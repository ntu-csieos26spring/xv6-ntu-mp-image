#!/bin/sh
set -euo pipefail

apt-get update -qq -y
apt-get install -qq -y --no-install-recommends sudo tmux procps gawk

# WORKAROUND (trixie only): upgrade libssl3t64 here so the newer copy lands in
# this layer. Otherwise a later apt layer (devtools/riscv) pulls it transitively
# as an upgrade, orphaning the base-layer libssl/libcrypto (~15 MB of dead
# weight visible to dive). Bookworm ships libssl3 without this churn. Remove
# once trixie's python:slim base catches up to current libssl3t64.
. /etc/os-release
if [ "$VERSION_CODENAME" = "trixie" ]; then
    apt-get install -qq -y --only-upgrade libssl3t64
fi
