#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$REPO_ROOT/configs/remote.conf}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Usage: ./scripts/buildx-remote-fg.sh [remote.conf]"
    exit 1
fi
source "$CONFIG_FILE"

$DOCKER_CMD run --rm --privileged -p $SLAVE_HOST:$SLAVE_BUILDKIT_PORT:1234 moby/buildkit:buildx-stable-1 --addr tcp://0.0.0.0:1234
