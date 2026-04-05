#!/bin/bash
# Build QEMU from source for RISC-V targets (builder stage)
# Adapted from mp2/setup.sh for Python 3.14 / Trixie

QEMU_VER="${QEMU_VERSION:-10.2.2}"

set -euo pipefail

QEMU_TARBALL="qemu-${QEMU_VER}.tar.xz"
CACHE_DIR="${QEMU_CACHE_DIR:-/tmp}"

cd /tmp
print_info "Using pre-verified QEMU ${QEMU_VER} tarball..."
cp "${CACHE_DIR}/${QEMU_TARBALL}" .

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
            --disable-kvm \
            --disable-alsa \
            --disable-pa \
            --disable-sndio
make -j"${CPU_COUNT}"
make install

# Cleanup source (reduces builder stage cache size)
cd /tmp
rm -rf "qemu-${QEMU_VER}" "${QEMU_TARBALL}"

print_info "QEMU ${QEMU_VER} build complete."
