#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/docker-detect.sh"

CURRENT_SHELL="$(basename "$SHELL")"
# Get the directory where THIS wrapper script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC2016
REPLACE_PATTERN="s/\$DOCKER_CMD/$DOCKER_CMD/g"

case "$CURRENT_SHELL" in
    bash)
        eval "$(sed "$REPLACE_PATTERN" "${SCRIPT_DIR}/va.complete.bash")"
        ;;
    zsh)
        eval "$(sed "$REPLACE_PATTERN" "${SCRIPT_DIR}/va.complete.zsh")"
        ;;
    *)
        echo "We do not have completions for this shell ($CURRENT_SHELL)."
esac

echo "Completions added for \`$DOCKER_CMD\`"
