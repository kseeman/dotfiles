#!/usr/bin/env bash
#
# Claude Code status line: context usage, cwd, git branch.
#
# Claude Code pipes a JSON payload on stdin (see
# https://code.claude.com/docs/en/statusline) and shows whatever this prints.
# `context_window.used_percentage` arrives pre-computed and is null until the
# first API response, so that segment is simply absent at session start.
#
# Needs jq, like the hooks beside it. Without jq there is nothing useful to
# print, so the line stays empty rather than guessing.

set -u

input=$(cat)

command -v jq &>/dev/null || exit 0

cwd=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
pct=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
model=$(jq -r '.model.display_name // .model.id // empty' <<<"$input")
effort=$(jq -r '.effort.level // empty' <<<"$input")

dim=$'\e[2m'
reset=$'\e[0m'
line=""

[[ -n "$model" ]] && line="$model"
[[ -n "$effort" ]] && line+="${line:+ }${dim}${effort}${reset}"

if [[ -n "$pct" ]]; then
    pct=${pct%.*}

    color=$'\e[32m'
    (( pct >= 50 )) && color=$'\e[33m'
    (( pct >= 80 )) && color=$'\e[31m'

    line="${line:+$line ${dim}·${reset} }${color}ctx ${pct}%${reset}"
fi

if [[ -n "$cwd" ]]; then
    # ${cwd/#$HOME/~} keeps the backslash the tilde needs to survive parsing,
    # because the replacement half of ${var/pat/repl} is not re-parsed. Same
    # gotcha as tmux-sessionizer; the tilde goes through a variable instead.
    tilde='~'
    line="${line:+$line ${dim}·${reset} }${cwd/#$HOME/$tilde}"

    branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null) ||
        branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null) || branch=""

    [[ -n "$branch" ]] && line+=" ${dim}on${reset} ${branch}"
fi

printf '%s' "$line"
