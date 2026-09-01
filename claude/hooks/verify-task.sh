#!/usr/bin/env bash
#
# Stop hook. Advisory only — it never blocks and never fails a turn.
#
# A shell script cannot judge whether Claude actually verified its work; that is
# a semantic question. What it can do is make the resulting state visible, so
# neither of us has to take "done" on trust. On every stop with a dirty working
# tree it prints a summary of what changed.
#
# Deliberately not a quality gate: no `decision: block`, no test running, no
# heuristics about whether validation "should" have happened. Those loop, or
# nag, or both. If usage shows a real need for enforcement, this is the place to
# add it.
#
# Protocol: read JSON on stdin, optionally emit {"systemMessage": ...} to show
# the user a notice, always exit 0.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"

# Set when this hook's own output caused Claude to continue. Returning quietly
# is what keeps a Stop hook from looping.
if [[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" == "true" ]]; then
    exit 0
fi

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[[ -n "$cwd" && -d "$cwd" ]] || exit 0

cd "$cwd" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

status="$(git status --porcelain 2>/dev/null)"
[[ -n "$status" ]] || exit 0

tracked_stat="$(git diff --shortstat 2>/dev/null | sed 's/^ *//')"
staged_stat="$(git diff --cached --shortstat 2>/dev/null | sed 's/^ *//')"
untracked_count="$(printf '%s\n' "$status" | grep -c '^??' || true)"

# Cap the list: this is a glance at the state, not a replacement for git status.
max_files=12
file_lines="$(printf '%s\n' "$status" | head -n "$max_files")"
total_files="$(printf '%s\n' "$status" | wc -l | tr -d ' ')"

message="Working tree in $(basename "$cwd") — $total_files changed path(s):"
message+=$'\n'"$file_lines"

if ((total_files > max_files)); then
    message+=$'\n'"  … $((total_files - max_files)) more"
fi

[[ -n "$staged_stat" ]] && message+=$'\n'"staged:   $staged_stat"
[[ -n "$tracked_stat" ]] && message+=$'\n'"unstaged: $tracked_stat"
[[ "$untracked_count" -gt 0 ]] && message+=$'\n'"untracked: $untracked_count file(s)"

message+=$'\n'"Review with: git diff"

jq -n --arg m "$message" '{systemMessage: $m}'

exit 0
