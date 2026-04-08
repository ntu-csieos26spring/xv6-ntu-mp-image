#!/bin/sh
set -euo pipefail

# fixuid: setuid root so it can remap student's UID to match -u flag
chown root:root /usr/local/bin/fixuid
chmod 4755 /usr/local/bin/fixuid
mkdir -p /etc/fixuid
printf "user: %s\ngroup: %s\npaths:\n  - %s\n" "${USER}" "${USER}" "${HOME}" > /etc/fixuid/config.yml
