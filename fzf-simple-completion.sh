#!/usr/bin/env bash

# FZF SIMPLE COMPLETION - Pipe bash tab-completion suggestions into fzf fuzzy finder
# More details at https://github.com/duong-db/fzf-simple-completion

bind '"\e[0n": redraw-current-line'
export FZF_DEFAULT_OPTS="--bind=tab:down --bind=btab:up --cycle"

_fzf_command_completion() {
    local cur
    _comp_get_words cur

    COMPREPLY=$(
        # Use compgen for commands completion
        compgen -c -- "$cur" 2>/dev/null | LC_ALL=C sort -u |
        fzf --reverse --height 12 --select-1 --exit-0
    )
    printf '\e[5n'
}

_fzf_get_argument_list() {
    source /usr/share/bash-completion/bash_completion
    local cmd="${COMP_WORDS[0]}"

    local cur prev
    _comp_get_words cur prev

    local comp_rule=$(complete -p "$cmd" 2>/dev/null)

    if [[ -z "$comp_rule" ]]; then
        # Load completion using _completion_loader from bash_completion script
        _completion_loader "$cmd" 2>/dev/null
        comp_rule=$(complete -p "$cmd" 2>/dev/null)
    fi

    if [[ "$comp_rule" =~ -F[[:space:]]+([^[:space:]]+) ]]; then
        # Function-based completion
        local _cmd="${BASH_REMATCH[1]}"
        "$_cmd" "$cmd" "$cur" "$prev" 2>/dev/null
    else
        # Flag-based completion
        local opts="${comp_rule#complete }"
        opts="${opts% $cmd}"
        mapfile -t COMPREPLY < <(compgen $opts -- "$cur" 2>/dev/null)
    fi

    # Fallback to default file completion if the specific completion function returned nothing
    if [[ "${#COMPREPLY[@]}" -eq 0 && "${_cmd:-}" == "_comp_complete_minimal" ]]; then
        mapfile -t COMPREPLY < <(compgen -f -- "$cur" 2>/dev/null)
    fi

    # Add colors
    for i in "${!COMPREPLY[@]}"; do
        # "~/Documents" is not recognized as a directory due to quotes so we need to expand tilde
        if [[ -e "${COMPREPLY[i]/#~/$HOME}" ]]; then
             COMPREPLY[i]=$(ls -F -d --color=always "${COMPREPLY[i]/#~/$HOME}" 2>/dev/null)
        fi
    done
    printf '%s\n' "${COMPREPLY[@]}" | LC_ALL=C sort -t '.' -k2
}

_fzf_argument_completion() {
    [[ "$COMP_CWORD" -eq 0 ]] && return
    local fzf_opts="--ansi --reverse --height 12 --select-1 --exit-0"

    # Hack on directories completion
    # - Only display the last sub directory for fzf searching
    #     Example. a/b/c/ -> a//b//c/ -> c/
    # - Handle the case where directory contains spaces
    #     Example. New Folder/ -> New\ Folder/
    # - Revert $HOME back to tilde
    COMPREPLY=$(
        _fzf_get_argument_list |
        sed 's|/|//|g; s|/$||' | fzf $fzf_opts -d '//' --with-nth='-1..' | sed 's|//|/|g' |
        sed 's| |\\ |g; s|\\ $| |' |
        sed "s|^$HOME|~|"
    )
    printf '\e[5n'
}

# Remove default completions
complete -r

# Set fuzzy completion
complete -o nospace -I -F _fzf_command_completion
complete -o nospace -D -F _fzf_argument_completion

# Turn off case sensitivity for better user experience
bind 'set completion-ignore-case on'