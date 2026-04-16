#!/usr/bin/env bash
# Detect whether docker needs sudo. Source this file to set DOCKER_CMD.
if docker info &>/dev/null; then
    DOCKER_CMD="docker"
else
    DOCKER_CMD="sudo docker"
fi
