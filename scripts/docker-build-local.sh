#!/usr/bin/env bash
set -euo pipefail

cat <<'WARN'
WARNING: Building multi-arch locally uses QEMU userspace emulation for the
non-native platform. This is significantly slower than native compilation.
Consider using the distributed build (docker-build-setup.sh + docker-build.sh) if you
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
    echo "Usage: ./scripts/docker-build-local.sh [-c config] [docker-options...]"
    exit 1
fi
source "$CONFIG_FILE"
source "$(dirname "${BASH_SOURCE[0]}")/docker-detect.sh"

$DOCKER_CMD buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "$ORGANIZATION/$IMAGE_NAME:$IMAGE_TAG" \
    --build-arg "REPOSOURCE=$REPOSITORY_SOURCE" \
    --build-arg "IMGDESC=$IMAGE_DESCRIPTION" \
    --build-arg "QEMU_VERSION=$QEMU_VERSION" \
    --build-arg "QEMU_GPG_KEY=$QEMU_GPG_KEY" \
    --build-arg "QEMU_RUNTIME_DEPS=$QEMU_RUNTIME_DEPS" \
    --build-arg "PYTHON_VERSION=$PYTHON_VERSION" \
    --build-arg "DEBIAN_SUITE=$DEBIAN_SUITE" \
    --annotation "index:org.opencontainers.image.description=$IMAGE_DESCRIPTION" \
    --annotation "index:org.opencontainers.image.source=$REPOSITORY_SOURCE" \
    "$@" \
    --push "$REPO_ROOT"
