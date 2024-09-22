#!/usr/bin/env bash

# FZF SIMPLE COMPLETION - Pipe bash tab-completion suggestions into fzf fuzzy finder
# More details at https://github.com/duong-db/fzf-simple-completion

bind '"\e[0n": redraw-current-line' 
export FZF_DEFAULT_OPTS="--bind=tab:down --bind=btab:up --cycle"

_fzf_command_completion() {
    [[ -z "${COMP_LINE// /}" || $COMP_POINT -ne ${#COMP_LINE} ]] && return
    COMPREPLY=$(
        # Use compgen for commands completion
        compgen -c -- "${COMP_WORDS[COMP_CWORD]}" 2>/dev/null | LC_ALL=C sort -u |
        fzf --reverse --height 12 --select-1 --exit-0
    )
    printf '\e[5n'
}

_fzf_get_argument_list() {
    local _command command=${COMP_LINE%% *}
    source /usr/share/bash-completion/bash_completion
    _command=$(complete -p "$command" 2>/dev/null | awk '{print $(NF-1)}')
    
    if [[ -z $_command ]]; then 
        # Load completion using _completion_loader from bash_completion script
        _completion_loader "$command"
        _command=$(complete -p "$command" 2>/dev/null | awk '{print $(NF-1)}')
    fi
    "$_command" 2>/dev/null

    # Add color
    for i in "${!COMPREPLY[@]}"; do
        # "~/Documents" is not recognized as a directory due to quotes so we need to expand tilde
        if [[ -e "${COMPREPLY[i]/#~/$HOME}" ]]; then
            COMPREPLY[i]=$(ls -F -d --color=always "${COMPREPLY[i]/#~/$HOME}" 2>/dev/null)
        fi
    done
    printf '%s\n' "${COMPREPLY[@]}" | LC_ALL=C sort -u | LC_ALL=C sort -t '.' -k2
}

_fzf_argument_completion() {
    [[ $COMP_POINT -ne ${#COMP_LINE} ]] && return
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