#!/bin/sh
set -euo pipefail

# setup user
useradd -m -G sudo "${USER}"
echo "${USER} ALL = NOPASSWD: ALL" > /etc/sudoers.d/"${USER}"
chmod 0440 /etc/sudoers.d/"${USER}"
passwd -d "${USER}"
