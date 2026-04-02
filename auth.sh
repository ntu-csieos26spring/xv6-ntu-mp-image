#!/bin/bash
set -euo pipefail

if [ $# != 1 ]; then
	echo "Usage: ./auth.sh <GitHub Username>"
	exit 1
fi

DOCKER_CMD="${DOCKER_CMD:-docker}"
gh auth login --scopes repo,read:packages,write:packages
gh auth token | $DOCKER_CMD login ghcr.io --username $1 --password-stdin
