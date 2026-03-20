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
    local cur
    _get_comp_words_by_ref cur

    COMPREPLY=$(
        # Use compgen for commands completion
        compgen -c -- "$cur" 2>/dev/null | LC_ALL=C sort -u |
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
        _fzf_get_argument_list |
        sed 's|/|//|g; s|/$||' | fzf $fzf_opts -d '//' --with-nth='-1..' | sed 's|//|/|g' |
        while IFS= read -r selected; do
            [[ -e $selected ]] && printf '%q' "$selected" || printf '%s' "$selected"
        done
    )
    printf '\e[5n'
}

# ------------------------------------
# Get argument completion candidates
# ------------------------------------
_fzf_get_argument_list() {
    local cur prev
    _get_comp_words_by_ref cur prev

    local cmd="${COMP_WORDS[0]}"
    local comp_rule="${FZF_BASH_DEFAULT_COMPS["$cmd"]}"

    if [[ -z "$comp_rule" ]]; then
        # Lazy load completion
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

    # Fallback to file completion
    if [[ "${#COMPREPLY[@]}" -eq 0 && "${_cmd:-}" == *"_minimal" ]]; then
        mapfile -t COMPREPLY < <(compgen -f -- "$cur" 2>/dev/null)
    fi

    # Add colors
    _fzf_colorize_compreply
    printf '%s\n' "${COMPREPLY[@]}" | awk '!seen[$0]++' | LC_ALL=C sort -t '.' -k2
}

# ------------------------------------
# Colorize COMPREPLY
# ------------------------------------
_fzf_colorize_compreply() {
    local i path ext color

    for i in "${!COMPREPLY[@]}"; do
        path="${COMPREPLY[i]/#~/$HOME}"
        color=""

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

        [[ -n "$color" ]] && COMPREPLY[i]=$'\e['"$color"$'m'"${COMPREPLY[i]}"$'\e[0m'
        [[ -d "$path" ]] && COMPREPLY[i]="${COMPREPLY[i]}/"
    done
}

# ------------------------------------
# LS_COLORS parser
# ------------------------------------
_fzf_init_ls_colors() {
    declare -gA FZF_LS_COLORS
    local c kv k v
    IFS=':' read -r -a c <<< "$(dircolors -b 2>/dev/null)"
    for kv in "${c[@]}"; do
        IFS='=' read -r k v <<< "${kv}"
        [[ -n "$k" && -n "$v" ]] && FZF_LS_COLORS["$k"]="$v"
    done
}
_fzf_init_ls_colors
unset -f _fzf_init_ls_colors

# ------------------------------------
# Bash default completions
# ------------------------------------
_fzf_init_default_completions() {
    declare -gA FZF_BASH_DEFAULT_COMPS
    while read -r line; do
        local cmd="${line##* }"
        [[ -n "$cmd" ]] && FZF_BASH_DEFAULT_COMPS["$cmd"]="$line"
    done < <(complete -p 2>/dev/null)
}
_fzf_init_default_completions
unset -f _fzf_init_default_completions

# ------------------------------------
# Register completion
# ------------------------------------
# Remove all existing completion
complete -r

# Add new completion rules
complete -o nospace -D -F _fzf_argument_completion
complete -o nospace -E -F _fzf_command_completion
complete -o nospace -I -F _fzf_command_completion