#!/bin/sh
set -euo pipefail

apt-get update -qq -y
apt-get install -qq -y --no-install-recommends sudo tmux procps gawk
apt-get install -qq -y --no-install-recommends git make gcc libc6-dev gdb-multiarch gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu libglib2.0-0 libpixman-1-0
# need to pin qemu dep packages
apt-get install -qq -y --no-install-recommends libpng16-16 libcurl4
