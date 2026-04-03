#!/usr/bin/env bash
set -euo pipefail

cat <<'WARN'
WARNING: Building multi-arch locally uses QEMU userspace emulation for the
non-native platform. This is significantly slower than native compilation.
Consider using the distributed build (buildx-setup.sh + buildx.sh) if you
have access to machines of both architectures.
WARN

CONFIG_FILE="${1:-build.conf}"
if [ ! -f "$CONFIG_FILE"]; then
    echo "Usage: ./buildx-local.sh [build.conf]"
    exit 1
fi
source "$CONFIG_FILE"

$DOCKER_CMD buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "$ORGANIZATION/$IMAGE_NAME:$IMAGE_TAG" \
    --build-arg "REPOSOURCE=$REPOSITORY_SOURCE" \
    --build-arg "IMGDESC=$IMAGE_DESCRIPTION" \
    --build-arg "QEMU_VERSION=$QEMU_VERSION" \
    --build-arg "PYTHON_VERSION=$PYTHON_VERSION" \
    --build-arg "DEBIAN_SUITE=$DEBIAN_SUITE" \
    --annotation "index:org.opencontainers.image.description=$IMAGE_DESCRIPTION" \
    --annotation "index:org.opencontainers.image.source=$REPOSITORY_SOURCE" \
    "$@" \
    --push .
