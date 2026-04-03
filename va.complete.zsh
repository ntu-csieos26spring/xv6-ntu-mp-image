#!/usr/bin/env zsh
set -o pipefail

_va_sh_completion() {
    # Only trigger on the first argument
    if [[ $CURRENT -eq 2 ]]; then
        local -a images

        # (@f) splits the command output by newlines into a proper Zsh array.
        # We redirect stderr to /dev/null to keep the prompt clean on errors.
        images=("${(@f)$($DOCKER_CMD images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')}") || return $?

        # If the array has items, feed it to Zsh's description engine
        if [[ ${#images[@]} -gt 0 && -n "$images[1]" ]]; then
            _describe 'docker images' images
        fi
    fi
    return 0
}

compdef _va_sh_completion va.sh ./va.sh
