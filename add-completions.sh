#!/usr/bin/env bash
DOCKER_CMD="${DOCKER_CMD:-docker}"

# Get the directory where THIS wrapper script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
eval "$(DOCKER_CMD="${DOCKER_CMD}" "${SCRIPT_DIR}/va.sh" --completion)"

echo "Completions added"
