#!/bin/bash
# Build QEMU from source for RISC-V targets (builder stage)
# Adapted from mp2/setup.sh for Python 3.14 / Trixie

QEMU_VER="${QEMU_VERSION:-10.2.2}"
PIP_BUILD_PKGS="ninja sphinx sphinx_rtd_theme tomli distlib wheel setuptools"

set -euo pipefail

print_info "Installing Python build packages..."
pip3 install --no-cache-dir --root-user-action=ignore --upgrade pip wheel setuptools
pip3 install --no-cache-dir --root-user-action=ignore $PIP_BUILD_PKGS

QEMU_TARBALL="qemu-${QEMU_VER}.tar.xz"
CACHE_DIR="${QEMU_CACHE_DIR:-/tmp}"

cd /tmp
if [ -f "${CACHE_DIR}/${QEMU_TARBALL}" ]; then
    print_info "Using cached QEMU ${QEMU_VER} tarball..."
    cp "${CACHE_DIR}/${QEMU_TARBALL}" .
else
    print_info "Downloading QEMU ${QEMU_VER}..."
    wget -q "https://download.qemu.org/${QEMU_TARBALL}"
    cp "${QEMU_TARBALL}" "${CACHE_DIR}/" 2>/dev/null || true
fi
print_info "Verifying QEMU ${QEMU_VER} signature..."
wget -q "https://download.qemu.org/${QEMU_TARBALL}.sig"
gpg --keyserver hkps://keys.openpgp.org --recv-keys CEACC9E15534EBABB82D3FA03353C9CEF108B584
gpg --verify "${QEMU_TARBALL}.sig" "${QEMU_TARBALL}"

print_info "Extracting and configuring QEMU..."
tar -xJf "${QEMU_TARBALL}"
cd "qemu-${QEMU_VER}"

CROSS_OPTS=""
if [ -n "${CROSS_PREFIX:-}" ]; then
    print_info "Cross-compiling with prefix: ${CROSS_PREFIX}"
    CROSS_OPTS="--cross-prefix=${CROSS_PREFIX}"
fi

CPU_COUNT=$(nproc)
print_info "Building QEMU with ${CPU_COUNT} cores..."
./configure --target-list=riscv64-softmmu \
            ${CROSS_OPTS} \
            --disable-docs \
            --disable-vnc \
            --disable-gtk \
            --disable-sdl \
            --disable-opengl \
            --disable-slirp \
            --disable-kvm
make -j"${CPU_COUNT}"
make install

# Cleanup source (reduces builder stage cache size)
cd /tmp
rm -rf "qemu-${QEMU_VER}" "${QEMU_TARBALL}"

print_info "QEMU ${QEMU_VER} build complete."
