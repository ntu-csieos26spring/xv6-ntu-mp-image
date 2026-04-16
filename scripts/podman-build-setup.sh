#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$REPO_ROOT/configs/podman-remote.conf}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Usage: ./scripts/podman-build-setup.sh [podman-remote.conf]"
    exit 1
fi
source "$CONFIG_FILE"
source "$(dirname "${BASH_SOURCE[0]}")/podman-detect.sh"

# Remove existing connection and farm if present
$PODMAN_CMD system connection rm "$CONNECTION_NAME" 2>/dev/null || true
$PODMAN_CMD farm rm "$FARM_NAME" 2>/dev/null || true

# Add remote connection via SSH
$PODMAN_CMD system connection add "$CONNECTION_NAME" \
    --identity "$SLAVE_SSH_KEY" \
    "ssh://${SLAVE_USER}@${SLAVE_HOST}${SLAVE_PODMAN_SOCKET}"

# Verify connection
echo "Verifying connection to '$CONNECTION_NAME'..."
$PODMAN_CMD --connection "$CONNECTION_NAME" info --format '{{.Host.Arch}}'

# Create farm with local + remote nodes
$PODMAN_CMD farm create "$FARM_NAME"
$PODMAN_CMD farm update --add "$CONNECTION_NAME" "$FARM_NAME"

echo "Farm '$FARM_NAME' is ready."
$PODMAN_CMD farm list
