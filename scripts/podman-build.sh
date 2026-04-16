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

BASE="$ORGANIZATION/$IMAGE_NAME"
LATEST="$BASE:latest"

# podman farm build does not support custom tags; build and push as :latest first
$PODMAN_CMD farm build \
    --farm "$FARM_NAME" \
    -t "$BASE" \
    --build-arg "REPOSOURCE=$REPOSITORY_SOURCE" \
    --build-arg "IMGDESC=$IMAGE_DESCRIPTION" \
    --build-arg "QEMU_VERSION=$QEMU_VERSION" \
    --build-arg "QEMU_GPG_KEY=$QEMU_GPG_KEY" \
    --build-arg "QEMU_RUNTIME_DEPS=$QEMU_RUNTIME_DEPS" \
    --build-arg "PYTHON_VERSION=$PYTHON_VERSION" \
    --build-arg "DEBIAN_SUITE=$DEBIAN_SUITE" \
    "$@" \
    "$REPO_ROOT"

# Re-tag if IMAGE_TAG is not "latest"
if [ "$IMAGE_TAG" = "latest" ]; then
    TAG="$LATEST"
else
    TAG="$BASE:$IMAGE_TAG"
    $PODMAN_CMD tag "$LATEST" "$TAG"
fi

# Tag arch-specific images by parsing manifest inspect output
MANIFEST_JSON="$($PODMAN_CMD manifest inspect "$LATEST")"
ARCH=""
DIGEST=""
ARCH_TAGS=()
while IFS= read -r line; do
    case "$line" in
        *'"architecture"'*)
            ARCH="$(echo "$line" | sed 's/.*"architecture"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
            ;;
        *'"digest"'*)
            DIGEST="$(echo "$line" | sed 's/.*"digest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
            ;;
    esac
    # When we have both arch and digest, tag and reset
    if [ -n "$ARCH" ] && [ -n "$DIGEST" ]; then
        if [ "$IMAGE_TAG" = "latest" ]; then
            ARCH_TAG="$BASE:$ARCH"
        else
            ARCH_TAG="$BASE:$IMAGE_TAG-$ARCH"
        fi
        $PODMAN_CMD tag "$DIGEST" "$ARCH_TAG"
        ARCH_TAGS+=("$ARCH_TAG")
        ARCH=""
        DIGEST=""
    fi
done <<< "$MANIFEST_JSON"

# Push re-tagged manifest and arch-specific images
# (:latest is already pushed by farm build)
if [ "$IMAGE_TAG" != "latest" ]; then
    $PODMAN_CMD manifest push --all "$TAG" "docker://$TAG"
fi
for ARCH_TAG in "${ARCH_TAGS[@]}"; do
    $PODMAN_CMD push "$ARCH_TAG" "docker://$ARCH_TAG"
done
