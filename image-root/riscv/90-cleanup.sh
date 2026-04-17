#!/bin/sh
set -euo pipefail

GCC_VERSION="$(riscv64-linux-gnu-gcc -dumpversion | cut -d. -f1)"

apt-get clean

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
    /usr/riscv64-linux-gnu/lib/libasan* \
    /usr/riscv64-linux-gnu/lib/libtsan* \
    /usr/riscv64-linux-gnu/lib/liblsan* \
    /usr/riscv64-linux-gnu/lib/libubsan* \
    /usr/riscv64-linux-gnu/lib/libstdc++* \
    /usr/riscv64-linux-gnu/lib/libgomp* \
    /usr/libexec/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/lto1 \
    /usr/libexec/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/lto-wrapper \
    /usr/bin/riscv64-linux-gnu-lto-dump-${GCC_VERSION} \
    /usr/bin/gdb \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libasan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libtsan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/liblsan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libubsan.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/${GCC_VERSION}/libgomp.a
