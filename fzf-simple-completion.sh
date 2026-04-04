#!/usr/bin/env bash

# FZF SIMPLE COMPLETION - Pipe bash tab-completion suggestions into fzf fuzzy finder
# More details at https://github.com/duong-db/fzf-simple-completion

# ------------------------------------
# Config
# ------------------------------------
bind '"\e[0n": redraw-current-line'
bind 'set completion-ignore-case on'

export FZF_DEFAULT_OPTS="--bind=tab:down,btab:up --cycle"

# ------------------------------------
# Command completion
# ------------------------------------
_fzf_command_completion() {
    local cur="$2"

    COMPREPLY=$(
        # Use compgen for commands completion
        compgen -c -- "$cur" 2>/dev/null | awk '!seen[$0]++' |
        fzf --reverse --height 12 --select-1 --exit-0
    )
    printf '\e[5n'
}

# ------------------------------------
# Argument completion
# ------------------------------------
_fzf_argument_completion() {
    [[ -z "${COMP_LINE// /}" ]] && return
    local fzf_opts="--ansi --reverse --height 12 --select-1 --exit-0"

    # Hack on directories completion
    # - Only display the last sub directory for fzf searching
    #     Example. a/b/c/ -> a//b//c/ -> c/
    # - Handle the case where directory contains spaces or special chars
    #     Example. New Folder/ -> New\ Folder/
    COMPREPLY=$(
        _fzf_get_argument_list "$@" | 
        _fzf_colorize_compreply | fzf $fzf_opts -d '//' --with-nth='-1..' | sed 's|//|/|g' |
        while IFS= read -r line; do
            local path="$line"
            __expand_tilde_by_ref path 2>/dev/null
            if [[ -e "$path" ]]; then
                [[ "$line" == \~* ]] && printf '~%q' "${line#\~}" || printf '%q' "$line"
            else
                printf '%s' "$line"
            fi
        done
    )
    printf '\e[5n'
}

# ------------------------------------
# Get argument completion candidates
# ------------------------------------
_fzf_get_argument_list() {

    # Resolve alias if it exists
    [[ ${BASH_ALIASES["$1"]} ]] && set -- ${BASH_ALIASES["$1"]} "${@:2}"
    local cmd="$1" cur="$2"

    # Load completion rule from the default
    local comp_rule="${FZF_BASH_DEFAULT_COMPS["$cmd"]}"

    if [[ -z "$comp_rule" ]]; then
        # Lazy load via _completion_loader
        _completion_loader "$cmd" 2>/dev/null
        comp_rule=$(complete -p "$cmd" 2>/dev/null)
    fi

    if [[ "$comp_rule" =~ -F[[:space:]]+([^[:space:]]+) ]]; then
        # Function-based completion (Example. complete -F _comp_complete_longopt ls)
        local _cmd="${BASH_REMATCH[1]}"
        "$_cmd" "$@" 2>/dev/null
    else
        # Flag-based completion (Example. complete -c which)
        local opts="${comp_rule#complete }"
        opts="${opts% $cmd}"
        mapfile -t COMPREPLY < <(compgen $opts -- "$cur" 2>/dev/null)
    fi
    
    # Fallback to file completion
    if [[ "${#COMPREPLY[@]}" -eq 0 && "${_cmd:-}" == *"_minimal" ]]; then
        mapfile -t COMPREPLY < <(compgen -f -- "$cur" 2>/dev/null)
    fi

    printf '%s\n' "${COMPREPLY[@]}" | awk '!seen[$0]++' | LC_ALL=C sort -t '.' -k2
}

# ------------------------------------
# Colorize COMPREPLY
# ------------------------------------
_fzf_colorize_compreply() {
    local line path ext color
    while IFS= read -r line; do
        path="$line"
        __expand_tilde_by_ref path 2>/dev/null

        if   [[ -L "$path" && -e "$path" ]]; then color="${FZF_LS_COLORS[ln]:-}" # symlink
        elif [[ -L "$path"               ]]; then color="${FZF_LS_COLORS[or]:-}" # broken symlink
        elif [[ -d "$path"               ]]; then color="${FZF_LS_COLORS[di]:-}" # directory
        elif [[ -p "$path"               ]]; then color="${FZF_LS_COLORS[pi]:-}" # pipe
        elif [[ -S "$path"               ]]; then color="${FZF_LS_COLORS[so]:-}" # socket
        elif [[ -b "$path"               ]]; then color="${FZF_LS_COLORS[bd]:-}" # block device
        elif [[ -c "$path"               ]]; then color="${FZF_LS_COLORS[cd]:-}" # character device
        elif [[ -u "$path"               ]]; then color="${FZF_LS_COLORS[su]:-}" # setuid
        elif [[ -g "$path"               ]]; then color="${FZF_LS_COLORS[sg]:-}" # setgid
        elif [[ -x "$path"               ]]; then color="${FZF_LS_COLORS[ex]:-}" # executable
        elif [[ -f "$path"               ]]; then 
            ext="${path##*.}"
            color="${FZF_LS_COLORS["*.$ext"]:-${FZF_LS_COLORS[fi]:-}}" # file
        fi
        
        [[ -n "$color" ]] && line=$'\e['"$color"$'m'"$line"$'\e[0m'
        [[ -e "$path" ]] && line="${line//\//\/\/}"
        [[ -d "$path" ]] && line+="/"

        printf '%s\n' "$line"
    done
}

# ------------------------------------
# LS_COLORS parser
# ------------------------------------
_fzf_init_ls_colors() {
    declare -gA FZF_LS_COLORS
    local k v
    while IFS='=' read -r k v; do
        [[ -n "$k" && -n "$v" ]] && FZF_LS_COLORS["$k"]="$v"
    done < <(dircolors -b 2>/dev/null | tr ':' '\n')
}
_fzf_init_ls_colors
unset -f _fzf_init_ls_colors

# ------------------------------------
# Bash default completions
# ------------------------------------
_fzf_init_default_completions() {
    declare -gA FZF_BASH_DEFAULT_COMPS
    local cmd line
    while read -r line; do
        cmd="${line##* }"
        [[ -n "$cmd" ]] && FZF_BASH_DEFAULT_COMPS["$cmd"]="$line"
    done < <(complete -p 2>/dev/null)
}
_fzf_init_default_completions
unset -f _fzf_init_default_completions

# ------------------------------------
# Register completions
# ------------------------------------
# Remove all existing completions
complete -r

# Add new completion rules
complete -o nospace -D -F _fzf_argument_completion
complete -o nospace -E -F _fzf_command_completion
complete -o nospace -I -F _fzf_command_completion