#!/bin/sh
set -euo pipefail

case "$TARGETARCH" in
    amd64) ARCH_TRIPLE="x86_64-linux-gnu" ;;
    arm64) ARCH_TRIPLE="aarch64-linux-gnu" ;;
    *)     ARCH_TRIPLE="${TARGETARCH}-linux-gnu" ;;
esac

GCC_VERSION="$(gcc -dumpversion | cut -d. -f1)"

apt-get clean

# remove the unused libraries
rm -rf /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /usr/share/doc/* \
    /usr/share/info/* \
    /usr/lib/${ARCH_TRIPLE}/libasan* \
    /usr/lib/${ARCH_TRIPLE}/libtsan* \
    /usr/riscv64-linux-gnu/lib/libasan* \
    /usr/riscv64-linux-gnu/lib/libtsan* \
    /usr/riscv64-linux-gnu/lib/liblsan* \
    /usr/riscv64-linux-gnu/lib/libubsan* \
    /usr/riscv64-linux-gnu/lib/libstdc++* \
    /usr/riscv64-linux-gnu/lib/libgomp* \
    /usr/share/perl/ \
    /usr/lib/${ARCH_TRIPLE}/perl/ \
    /usr/libexec/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/lto1 \
    /usr/libexec/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/lto-wrapper \
    /usr/libexec/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/lto1 \
    /usr/libexec/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/lto-wrapper \
    /usr/bin/${ARCH_TRIPLE}-lto-dump-${GCC_VERSION} \
    /usr/bin/${ARCH_TRIPLE}-gcov* \
    /usr/bin/riscv64-linux-gnu-lto-dump-${GCC_VERSION} \
    /usr/bin/gdb \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libasan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libtsan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/liblsan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libubsan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libgomp.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libasan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libtsan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/liblsan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libubsan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libgomp.a \
    /usr/lib/${ARCH_TRIPLE}/liblsan* \
    /usr/lib/${ARCH_TRIPLE}/libubsan*

if [ "$TARGETARCH" = "amd64" ]; then
    rm -rf \
        /usr/lib/${ARCH_TRIPLE}/libhwasan* \
        /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libhwasan.a
fi
