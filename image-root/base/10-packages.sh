#!/bin/sh
set -euo pipefail

apt-get update -qq -y
apt-get install -qq -y --no-install-recommends sudo tmux procps gawk
