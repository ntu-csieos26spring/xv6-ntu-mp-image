DOCKER_CMD="docker"
NO_CACHE=""
for arg in "$@"; do
    [ "$arg" = "--no-cache" ] && NO_CACHE="--no-cache"
done

"$DOCKER_CMD" buildx build \
    --builder cluster-builder \
    --platform linux/amd64,linux/arm64 \
    -f Dockerfile.trixie \
    -t ghcr.io/ntu-csieos26spring/mp-draft:latest \
    --annotation "index:org.opencontainers.image.description=general heavily stripped xv6 image for machine problems" \
    --annotation "index:org.opencontainers.image.source=https://github.com/ntu-csieos26spring/2026ta-wg" \
    $NO_CACHE \
    --push .
