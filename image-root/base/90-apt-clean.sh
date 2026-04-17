#!/bin/sh
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    /var/cache/debconf/*-old /var/lib/dpkg/*-old \
    /var/log/dpkg.log /var/log/apt/* /var/log/alternatives.log
