#!/bin/sh
set -euo pipefail

case "$TARGETARCH" in
    amd64) ARCH_TRIPLE="x86_64-linux-gnu" ;;
    arm64) ARCH_TRIPLE="aarch64-linux-gnu" ;;
    *)     ARCH_TRIPLE="${TARGETARCH}-linux-gnu" ;;
esac

GCC_VERSION="$(gcc -dumpversion | cut -d. -f1)"

apt-get clean

# remove the unused native libraries
rm -rf /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /var/cache/debconf/*-old \
    /var/lib/dpkg/*-old \
    /var/log/dpkg.log \
    /var/log/apt/* \
    /var/log/alternatives.log \
    /usr/share/doc/* \
    /usr/share/info/* \
    /usr/lib/${ARCH_TRIPLE}/libasan* \
    /usr/lib/${ARCH_TRIPLE}/libtsan* \
    /usr/lib/${ARCH_TRIPLE}/liblsan* \
    /usr/lib/${ARCH_TRIPLE}/libubsan* \
    /usr/share/perl/ \
    /usr/lib/${ARCH_TRIPLE}/perl/ \
    /usr/libexec/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/lto1 \
    /usr/libexec/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/lto-wrapper \
    /usr/bin/${ARCH_TRIPLE}-lto-dump-${GCC_VERSION} \
    /usr/bin/${ARCH_TRIPLE}-gcov* \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libasan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libtsan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/liblsan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libubsan.a \
    /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libgomp.a

if [ "$TARGETARCH" = "amd64" ]; then
    rm -rf \
        /usr/lib/${ARCH_TRIPLE}/libhwasan* \
        /usr/lib/gcc/${ARCH_TRIPLE}/${GCC_VERSION}/libhwasan.a
fi
