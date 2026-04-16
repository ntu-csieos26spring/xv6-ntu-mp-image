#!/bin/bash
set -euo pipefail

if [ $# -ge 1 ]; then
	USERNAME="$1"
else
	read -rp "GitHub Username: " USERNAME
	if [ -z "$USERNAME" ]; then
		echo "Username cannot be empty"
		exit 1
	fi
fi

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

echo "Select container runtime:"
echo "  1) docker"
echo "  2) podman"
read -rp "Choice [1]: " choice
choice="${choice:-1}"

case "$choice" in
	1) source "$SCRIPT_DIR/docker-detect.sh"; CMD="$DOCKER_CMD" ;;
	2) source "$SCRIPT_DIR/podman-detect.sh"; CMD="$PODMAN_CMD" ;;
	*) echo "Invalid choice"; exit 1 ;;
esac

gh auth login --scopes read:packages,write:packages
gh auth token | $CMD login ghcr.io --username "$USERNAME" --password-stdin
