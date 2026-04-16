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
MASTER_ARCH="${MASTER_PLATFORM##*/}"
SLAVE_ARCH="${SLAVE_PLATFORM##*/}"

BUILD_ARGS=(
    --build-arg "REPOSOURCE=$REPOSITORY_SOURCE"
    --build-arg "IMGDESC=$IMAGE_DESCRIPTION"
    --build-arg "QEMU_VERSION=$QEMU_VERSION"
    --build-arg "QEMU_GPG_KEY=$QEMU_GPG_KEY"
    --build-arg "QEMU_RUNTIME_DEPS=$QEMU_RUNTIME_DEPS"
    --build-arg "PYTHON_VERSION=$PYTHON_VERSION"
    --build-arg "DEBIAN_SUITE=$DEBIAN_SUITE"
)

# Build and push master platform (local)
echo "=== Building $MASTER_PLATFORM (local) ==="
$PODMAN_CMD build --platform "$MASTER_PLATFORM" \
    -t "$TAG-$MASTER_ARCH" "${BUILD_ARGS[@]}" "$@" "$REPO_ROOT"
$PODMAN_CMD push "$TAG-$MASTER_ARCH"

# Build and push slave platform (remote)
echo "=== Building $SLAVE_PLATFORM (remote: $CONNECTION_NAME) ==="
$PODMAN_CMD --connection "$CONNECTION_NAME" build --platform "$SLAVE_PLATFORM" \
    -t "$TAG-$SLAVE_ARCH" "${BUILD_ARGS[@]}" "$@" "$REPO_ROOT"
$PODMAN_CMD --connection "$CONNECTION_NAME" push "$TAG-$SLAVE_ARCH"

# Create and push manifest list
echo "=== Creating manifest list ==="
$PODMAN_CMD manifest rm "$TAG" 2>/dev/null || true
$PODMAN_CMD manifest create "$TAG" \
    "docker://$TAG-$MASTER_ARCH" \
    "docker://$TAG-$SLAVE_ARCH"
$PODMAN_CMD manifest push --all "$TAG" "docker://$TAG"
