#!/usr/bin/env bash
set -o pipefail

_va_sh_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local images
        images=$($DOCKER_CMD images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>") || return $?
        if [[ -z "$images" ]]; then
            COMPREPLY=()
            return 0
        fi
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "${images}" -- "${cur}") )
    else
        COMPREPLY=()
    fi
    return 0
}

complete -o nospace -F _va_sh_completion "./va.sh" "$(basename "./va.sh")"
