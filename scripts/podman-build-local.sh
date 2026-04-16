#!/usr/bin/env bash
set -euo pipefail

cat <<'WARN'
WARNING: Building multi-arch locally uses QEMU userspace emulation for the
non-native platform. This is significantly slower than native compilation.
Consider using the distributed build (podman-build-setup.sh + podman-build.sh) if you
have access to machines of both architectures.
WARN

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/configs/build.conf"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) CONFIG_FILE="$2"; shift 2 ;;
        *) break ;;
    esac
done
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Usage: ./scripts/podman-build-local.sh [-c config] [podman-options...]"
    exit 1
fi
source "$CONFIG_FILE"
source "$(dirname "${BASH_SOURCE[0]}")/podman-detect.sh"

TAG="$ORGANIZATION/$IMAGE_NAME:$IMAGE_TAG"

$PODMAN_CMD manifest rm "$TAG" 2>/dev/null || true
$PODMAN_CMD build \
    --platform linux/amd64,linux/arm64 \
    --manifest "$TAG" \
    --build-arg "REPOSOURCE=$REPOSITORY_SOURCE" \
    --build-arg "IMGDESC=$IMAGE_DESCRIPTION" \
    --build-arg "QEMU_VERSION=$QEMU_VERSION" \
    --build-arg "QEMU_GPG_KEY=$QEMU_GPG_KEY" \
    --build-arg "QEMU_RUNTIME_DEPS=$QEMU_RUNTIME_DEPS" \
    --build-arg "PYTHON_VERSION=$PYTHON_VERSION" \
    --build-arg "DEBIAN_SUITE=$DEBIAN_SUITE" \
    "$@" \
    "$REPO_ROOT"

$PODMAN_CMD manifest push --all "$TAG" "docker://$TAG"
