#!/bin/sh
set -euo pipefail

if [ "$USE_SYSTEMD" != "yes" ]; then
    return 0
fi

apt-get install -qq -y --no-install-recommends dbus dbus-x11 systemd
systemctl enable systemd-timedated
