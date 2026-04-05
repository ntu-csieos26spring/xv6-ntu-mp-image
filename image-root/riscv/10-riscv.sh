#!/bin/sh
set -euo pipefail

apt-get update -qq -y
apt-get install -qq -y --no-install-recommends \
    gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu gdb-multiarch
