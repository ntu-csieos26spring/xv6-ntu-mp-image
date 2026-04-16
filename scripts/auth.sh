#!/bin/bash
set -euo pipefail

if [ $# != 1 ]; then
	echo 'Usage: ./scripts/auth.sh <GitHub Username>'
	exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/docker-detect.sh"
gh auth login --scopes read:packages,write:packages
gh auth token | $DOCKER_CMD login ghcr.io --username "$1" --password-stdin
