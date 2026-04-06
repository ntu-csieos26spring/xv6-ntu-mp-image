#!/usr/bin/env bash
set -euo pipefail

export DOCKER_CLIENT_TIMEOUT=300

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/configs/build.conf"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) CONFIG_FILE="$2"; shift 2 ;;
        *) break ;;
    esac
done
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Usage: [DOCKER_CMD=\"sudo docker\"] ./scripts/buildx.sh [-c config] [docker-options...]"
    exit 1
fi
source "$CONFIG_FILE"

DOCKER_CMD="${DOCKER_CMD:-docker}"
$DOCKER_CMD buildx build \
    --builder cluster-builder \
    --platform linux/amd64,linux/arm64 \
    -t "$ORGANIZATION/$IMAGE_NAME:$IMAGE_TAG"\
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
    --output type=image,compression=zstd,compression-level=10,push=true \
    "$REPO_ROOT"
