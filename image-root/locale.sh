#!/bin/sh
set -euo pipefail

apt-get install -qq -y --no-install-recommends locales tzdata

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen

ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime
echo ${TZ} > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
