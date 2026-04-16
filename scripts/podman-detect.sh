#!/usr/bin/env bash
# Detect whether podman needs sudo. Source this file to set PODMAN_CMD.
if podman info &>/dev/null; then
    PODMAN_CMD="podman"
else
    PODMAN_CMD="sudo podman"
fi
