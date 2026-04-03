#!/usr/bin/env bash
set -euo pipefail

BUILD_CONF="${1:-build.conf}"
REMOTE_CONF="${2:-remote.conf}"
if [ ! -f "$BUILD_CONF" ] || [ ! -f "$REMOTE_CONF" ]; then
    echo "Usage: ./buildx-remote-fg.sh [build.conf] [remote.conf]"
    exit 1
fi
source "$BUILD_CONF"
source "$REMOTE_CONF"

$DOCKER_CMD run --rm --privileged -p $SLAVE_HOST:$SLAVE_BUILDKIT_PORT:1234 moby/buildkit:buildx-stable-1 --addr tcp://0.0.0.0:1234
