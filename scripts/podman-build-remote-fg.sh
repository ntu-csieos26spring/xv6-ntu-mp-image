#!/usr/bin/env bash
set -euo pipefail

# Run this on the remote (slave) node to start the podman API socket.
# Alternatively, enable the systemd user service:
#   systemctl --user enable --now podman.socket

source "$(dirname "${BASH_SOURCE[0]}")/podman-detect.sh"

echo "Starting podman socket listener..."
echo "Press Ctrl+C to stop."
$PODMAN_CMD system service --time=0
