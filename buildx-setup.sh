#!/usr/bin/env bash
set -euo pipefail

export DOCKER_CLIENT_TIMEOUT=300

CONFIG_FILE="${1:-remote.conf}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Usage: [DOCKER_CMD="sudo docker"] ./buildx-setup.sh [remote.conf]"
    exit 1
fi
source "$CONFIG_FILE"

DOCKER_CMD="${DOCKER_CMD:-docker}"
# remove the existing things
$DOCKER_CMD buildx rm cluster-builder > /dev/null 2>&1 || true

# start local buildkitd (listen on localhost only)
$DOCKER_CMD rm -f buildkitd-master >/dev/null 2>&1 || true
$DOCKER_CMD run --rm -d --name buildkitd-master --privileged \
  -p "${MASTER_HOST}:${MASTER_BUILDKIT_PORT}:1234" \
  moby/buildkit:buildx-stable-1 --addr tcp://0.0.0.0:1234

# wait for buildkitd to be ready
for i in $(seq 10 -1 1); do
  if $DOCKER_CMD logs buildkitd-master 2>&1 | grep -q "running server"; then
    echo "buildkitd-master is ready"
    break
  fi
  echo "waiting for buildkitd-master... ${i}s"
  sleep 1
done

# multi-node builder (both using remote driver)
$DOCKER_CMD buildx create --name cluster-builder --use --node master_node --platform "${MASTER_PLATFORM} --driver remote tcp://${MASTER_HOST}:${MASTER_BUILDKIT_PORT}"
$DOCKER_CMD buildx create --name cluster-builder --append --node slave_node --platform "${SLAVE_PLATFORM} --driver remote tcp://${SLAVE_HOST}:${SLAVE_BUILDKIT_PORT}"

# Bootstrap and verify
$DOCKER_CMD buildx inspect cluster-builder --bootstrap
