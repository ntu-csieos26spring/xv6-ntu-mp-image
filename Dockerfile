# syntax=docker/dockerfile:1.4
# Version pins (used across stages — must be declared before first FROM)
ARG QEMU_VERSION=10.2.2
ARG QEMU_GPG_KEY=CEACC9E15534EBABB82D3FA03353C9CEF108B584
ARG PYTHON_VERSION=3.14
ARG DEBIAN_SUITE=trixie

###############################################
# Stage 0: Download + verify QEMU source tarball
# Depends only on QEMU_VERSION and GPG key — fully
# cached regardless of DEBIAN_SUITE or PYTHON_VERSION.
###############################################
FROM --platform=$BUILDPLATFORM alpine:3.23 AS qemu-source

ARG QEMU_VERSION
ARG QEMU_GPG_KEY

RUN <<EOF
set -euo pipefail
apk add --no-cache wget gnupg
wget -q "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz"
wget -q "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz.sig"
gpg --keyserver hkps://keys.openpgp.org --recv-keys "$QEMU_GPG_KEY"
gpg --verify "qemu-${QEMU_VERSION}.tar.xz.sig" "qemu-${QEMU_VERSION}.tar.xz"
rm -f "qemu-${QEMU_VERSION}.tar.xz.sig"
EOF

###############################################
# Stage 1a: Build QEMU + shell tools from source
# Uses debian base (not python:) so PYTHON_VERSION changes don't
# invalidate the QEMU build cache.
###############################################
FROM --platform=$BUILDPLATFORM debian:${DEBIAN_SUITE} AS builder

ARG QEMU_VERSION
ARG TARGETARCH
ARG BUILDARCH

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /

# Prepare packages, if need to cross compile, prepare the target arch packages
RUN <<EOF
apt-get update -qq -y
apt-get install -qq -y python3 python3-sphinx python3-sphinx-rtd-theme \
    meson ninja-build pkg-config gawk git make gcc libc6-dev \
    libglib2.0-dev libpixman-1-dev zlib1g-dev \
    libgnutls28-dev libsasl2-dev libgtk-3-dev libsdl2-dev libepoxy-dev libslirp-dev
if [ "$TARGETARCH" != "$BUILDARCH" ]; then
    case "$TARGETARCH" in
        arm64) dpkg --add-architecture arm64 && apt-get update -qq -y && apt-get install -qq -y gcc-aarch64-linux-gnu libglib2.0-dev:arm64 libpixman-1-dev:arm64 zlib1g-dev:arm64 ;;
        amd64) dpkg --add-architecture amd64 && apt-get update -qq -y && apt-get install -qq -y gcc-x86-64-linux-gnu libglib2.0-dev:amd64 libpixman-1-dev:amd64 zlib1g-dev:amd64 ;;
    esac
fi
mkdir -p /scripts
EOF

COPY run-with-utils.sh /scripts/run-with-utils.sh
COPY utils/ /scripts/utils/
COPY qemu-build/ /scripts/qemu-build

# Pre-verified tarball from qemu-source stage (layer-cached, no re-download)
COPY --from=qemu-source /qemu-${QEMU_VERSION}.tar.xz /qemu-cache/

ENV QEMU_VERSION=${QEMU_VERSION}
RUN /bin/bash <<EOF
set -euo pipefail
CROSS_PREFIX=""
if [ "$TARGETARCH" != "$BUILDARCH" ]; then
    case "$TARGETARCH" in
        arm64) CROSS_PREFIX="aarch64-linux-gnu-" ;;
        amd64) CROSS_PREFIX="x86_64-linux-gnu-" ;;
    esac
fi
export CROSS_PREFIX
QEMU_CACHE_DIR=/qemu-cache . /scripts/run-with-utils.sh setup_all_plugins_in /scripts/qemu-build
EOF

RUN <<EOF
git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
mkdir -p /ble
make -C ble.sh install PREFIX=/ble
EOF

# smuggle the install script (clone avoids raw.githubusercontent.com which may be blocked)
RUN <<EOF
git clone --depth 1 https://github.com/ohmybash/oh-my-bash.git /tmp/oh-my-bash
cp /tmp/oh-my-bash/tools/install.sh /ble/omb-install.sh
rm -rf /tmp/oh-my-bash
EOF

###############################################
# Stage 1b: Build fixuid (avoids GitHub CDN)
###############################################
FROM --platform=$BUILDPLATFORM golang:1-${DEBIAN_SUITE} AS fixuid-builder
ARG TARGETARCH
ARG DEBIAN_SUITE
RUN <<EOF
GOOS=linux GOARCH=${TARGETARCH} CGO_ENABLED=0 \ 
go install github.com/boxboat/fixuid@v0.6.0
find /go/bin -name fixuid -exec install -m 0755 {} /usr/local/bin/fixuid \;
EOF

###############################################
# Stage 2: Cherry-pick runtime scripts
###############################################
FROM scratch AS scripts

# Root-owned files → COPY to /
COPY --from=builder /usr/local/bin/qemu-system-riscv64 /rootfs/usr/local/bin/qemu-system-riscv64
COPY --from=builder /usr/local/share/qemu/opensbi-riscv64-generic-fw_dynamic.bin /rootfs/usr/local/share/qemu/opensbi-riscv64-generic-fw_dynamic.bin
COPY --from=fixuid-builder /usr/local/bin/fixuid /rootfs/usr/local/bin/fixuid
COPY image-configs/tmux.conf /rootfs/etc/tmux.conf

# User-owned files → COPY to ${HOME}
COPY --from=builder /ble/ /homefs/.local/

###############################################
# Stage 3: Final slim image
###############################################
ARG PYTHON_VERSION
ARG DEBIAN_SUITE
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_SUITE} AS runner

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

USER root

# L0: Binary artifacts (QEMU, fixuid, /etc configs)
COPY --from=scripts /rootfs/ /

# L1: System utilities + locale
ARG TARGETARCH
ARG LOCALE=C.UTF-8
ARG TZ=Asia/Taipei
COPY image-root/base/ /root/stage/
RUN /bin/bash <<EOF
set -euo pipefail
for s in /root/stage/*.sh; do . "\$s"; done
rm -rf /root/stage
EOF

# Layers ordered by change frequency (least → most volatile).
# L2: User + fixuid — no dependency on devtools (just useradd/chown from base)
ARG USER=student
ARG HOME=/home/student
COPY image-root/user/ /root/stage/
RUN /bin/bash <<EOF
set -euo pipefail
for s in /root/stage/*.sh; do . "\$s"; done
rm -rf /root/stage
EOF

# L3: Systemd (conditional, self-contained)
ARG USE_SYSTEMD=no
COPY image-root/systemd/ /root/stage/
RUN /bin/bash <<EOF
set -euo pipefail
for s in /root/stage/*.sh; do . "\$s"; done
rm -rf /root/stage
EOF

# L4: Dev tools + QEMU runtime deps + targeted cleanup
ARG QEMU_RUNTIME_DEPS="libpng16-16 libcurl4"
COPY image-root/devtools/ /root/stage/
RUN /bin/bash <<EOF
set -euo pipefail
for s in /root/stage/*.sh; do . "\$s"; done
rm -rf /root/stage
EOF

# L5: Pip — installs as root (no user dependency) but changes most often
COPY image-root/pip/ /root/stage/
RUN /bin/bash <<EOF
set -euo pipefail
for s in /root/stage/*.sh; do . "\$s"; done
rm -rf /root/stage
EOF

# Runtime ENVs placed late to avoid busting build layer caches
ENV USER=${USER}
ENV LC_ALL=${LOCALE}
ENV LANG=${LOCALE}
ENV TERM=xterm-256color

USER ${USER}
WORKDIR ${HOME}

# L6: User-owned files (ble.sh, oh-my-bash installer)
COPY --chown=${USER}:${USER} --from=scripts /homefs/ ${HOME}/

# L7: User shell configuration
RUN /bin/bash <<EOF
set -euo pipefail
echo -e "[\e[1;34mINFO\e[0m] Setup user $USER"
# gdb safe-path
mkdir -p $HOME/.config/gdb
echo "add-auto-load-safe-path $HOME/xv6/.gdbinit" > $HOME/.config/gdb/gdbinit
# script installation
bash $HOME/.local/omb-install.sh
sed -i 's/^OSH_THEME=.*/OSH_THEME="vscode"/' $HOME/.bashrc
sed -i '/^completions=(/,/^)/c\completions=(\n  git\n  pip3\n  tmux\n  makefile\n)' $HOME/.bashrc
rm $HOME/.local/omb-install.sh
# fake history to prevent "no history hang"
echo "ls" > $HOME/.bash_history
echo 'source -- $HOME/.local/share/blesh/ble.sh' >> $HOME/.bashrc
EOF

# L8: Optional password (most volatile ARGs declared last)
ARG USER_PSWD=CHANGE_ME
ARG USE_USER_PSWD=no
RUN ([ $USE_USER_PSWD = yes ] && \
    echo "${USER}:${USER_PSWD}" | sudo chpasswd) || \
    true

# OCI labels at very end — metadata changes never bust any RUN cache
ARG TARGETPLATFORM
ARG REPOSOURCE
ARG IMGDESC
LABEL org.opencontainers.image.architecture="${TARGETARCH}" \
      org.opencontainers.image.platform="${TARGETPLATFORM}" \
      org.opencontainers.image.description="${IMGDESC}" \
      org.opencontainers.image.source="${REPOSOURCE}"

ENTRYPOINT ["fixuid", "-q"]
CMD ["/bin/bash"]
