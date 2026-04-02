export DOCKER_CLIENT_TIMEOUT=300
DOCKER_CMD="docker"
NO_CACHE=""
for arg in "$@"; do
    [ "$arg" = "--no-cache" ] && NO_CACHE="--no-cache"
done

REPOSOURCE="https://github.com/ntu-csieos26spring/xv6-ntu-mp-image"
IMGDESC="general heavily stripped xv6 image for machine problems"

"$DOCKER_CMD" buildx build \
    --builder cluster-builder \
    --platform linux/amd64,linux/arm64 \
    -t ghcr.io/ntu-csieos26spring/mp-draft:latest \
    --build-arg "REPOSOURCE=$REPOSOURCE" \
    --build-arg "IMGDESC=$IMGDESC" \
    --annotation "index:org.opencontainers.image.description=$IMGDESC" \
    --annotation "index:org.opencontainers.image.source=$REPOSOURCE" \
    $NO_CACHE \
    --push .
