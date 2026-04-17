#!/bin/sh
set -euo pipefail

# fixuid binary arrives setuid-root from the storage stage (--chmod=4755).
mkdir -p /etc/fixuid
printf "user: %s\ngroup: %s\npaths:\n  - %s\n" "${USER}" "${USER}" "${HOME}" > /etc/fixuid/config.yml
