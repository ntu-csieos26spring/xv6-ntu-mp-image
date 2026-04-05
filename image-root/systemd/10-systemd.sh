#!/bin/sh
set -euo pipefail

if [ "$USE_SYSTEMD" != "yes" ]; then
    return 0
fi

apt-get update -qq -y
apt-get install -qq -y --no-install-recommends dbus dbus-x11 systemd
systemctl enable systemd-timedated
apt-get clean
rm -rf /var/lib/apt/lists/*
