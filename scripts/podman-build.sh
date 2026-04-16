#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/configs/build.conf"
REMOTE_CONFIG="$REPO_ROOT/configs/podman-remote.conf"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) CONFIG_FILE="$2"; shift 2 ;;
        -r) REMOTE_CONFIG="$2"; shift 2 ;;
        *) break ;;
    esac
done
if [ ! -f "$CONFIG_FILE" ] || [ ! -f "$REMOTE_CONFIG" ]; then
    echo "Usage: ./scripts/podman-build.sh [-c build.conf] [-r podman-remote.conf] [podman-options...]"
    exit 1
fi
source "$CONFIG_FILE"
source "$REMOTE_CONFIG"
source "$(dirname "${BASH_SOURCE[0]}")/podman-detect.sh"

TAG="$ORGANIZATION/$IMAGE_NAME:$IMAGE_TAG"

$PODMAN_CMD farm build \
    --farm "$FARM_NAME" \
    -t "$TAG" \
    --build-arg "REPOSOURCE=$REPOSITORY_SOURCE" \
    --build-arg "IMGDESC=$IMAGE_DESCRIPTION" \
    --build-arg "QEMU_VERSION=$QEMU_VERSION" \
    --build-arg "QEMU_GPG_KEY=$QEMU_GPG_KEY" \
    --build-arg "QEMU_RUNTIME_DEPS=$QEMU_RUNTIME_DEPS" \
    --build-arg "PYTHON_VERSION=$PYTHON_VERSION" \
    --build-arg "DEBIAN_SUITE=$DEBIAN_SUITE" \
    "$@" \
    "$REPO_ROOT"
