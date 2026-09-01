#!/usr/bin/env bash
#
# PreToolUse hook (matcher: Bash).
#
# Blocks git operations that can destroy local work or reach a remote, and asks
# before the ones that need my explicit say-so. Permission rules in
# settings.json cover the same ground ergonomically, but they match on a command
# prefix — `cd foo && git push` slips past them. This hook sees the whole
# command string, so it doesn't.
#
# Protocol: read the tool call as JSON on stdin, optionally write a decision to
# stdout, always exit 0. Emitting nothing means "no opinion" and normal
# permission handling continues.
#
#   deny  Claude cannot run it at all, and is told to ask me to run it myself.
#   ask   I get a prompt. For `git push` that prompt *is* the explicit
#         permission CLAUDE.md requires, so pushing stays possible.

set -uo pipefail

# Fail open. This hook is defence in depth, not the only layer: settings.json
# also carries `ask` rules for push and amend, so a machine without jq is
# degraded rather than unprotected.
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
command_line="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"

[[ -n "$command_line" ]] || exit 0

decide() {
    local decision="$1" reason="$2"

    jq -n \
        --arg decision "$decision" \
        --arg reason "$reason" \
        '{hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: $decision,
            permissionDecisionReason: $reason
        }}'

    exit 0
}

# Split on shell separators so each command is judged on its own. Without this,
# a chained command would have to be matched as one blob, and the patterns below
# could not anchor on "the segment starts with git".
#
# Quote-aware, which is not optional. A separator inside quotes does not start a
# new command, so a JSON payload or a grep pattern that happens to contain a
# chained git command must stay a single segment beginning with its real
# program. Splitting naively there invents a segment that begins with `git` and
# blocks it — which makes writing *about* git commands (documentation, test
# fixtures, search patterns) impossible.
split_segments() {
    printf '%s' "$1" | tr '\n' ' ' | awk '
    {
        single = 0
        double = 0
        segment = ""

        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)

            if (c == "\047" && !double) { single = !single; segment = segment c; continue }
            if (c == "\"" && !single)   { double = !double; segment = segment c; continue }

            if (!single && !double && (c == ";" || c == "&" || c == "|" || c == "`" || c == "(" || c == ")")) {
                print segment
                segment = ""
                continue
            }

            segment = segment c
        }

        print segment
    }'
}

segments="$(split_segments "$command_line")"

# Reduce one segment to the git arguments after the subcommand's global options,
# or nothing if the segment does not invoke git. Done in bash rather than sed
# because BSD and GNU sed disagree about labelled loops, and this has to run on
# both macOS and Linux.
#
#   sudo git -C /repo push origin main   ->   push origin main
#   npm test                             ->   (nothing)
git_args() {
    local -a words
    local i=0 n

    read -r -a words <<< "$1"
    n=${#words[@]}

    # sudo, and `env FOO=bar` style prefixes
    while ((i < n)); do
        case "${words[i]}" in
            sudo|env|*=*) ((i++)) ;;
            *) break ;;
        esac
    done

    [[ "${words[i]:-}" == "git" ]] || return 0
    ((i++))

    # git's own options, which sit before the subcommand
    while ((i < n)); do
        case "${words[i]}" in
            -C|-c|--git-dir|--work-tree|--namespace|--exec-path) ((i += 2)) ;;
            -*) ((i++)) ;;
            *) break ;;
        esac
    done

    printf '%s' "${words[*]:i}"
}

has() { printf '%s' "$1" | grep -qE "$2"; }

while IFS= read -r segment; do
    args="$(git_args "$segment")"
    [[ -n "$args" ]] || continue

    # A short option bundle containing the letter, e.g. -fd matches -[a-z]*f.
    # ------------------------------------------------------------------ deny

    if has "$args" '^push([[:space:]]|$)'; then
        if has "$args" '(^|[[:space:]])(--force|--force-with-lease([=[:space:]]|$)|-[a-zA-Z]*f([[:space:]]|$))'; then
            decide deny "Force push blocked. Force pushing rewrites published history and can destroy work on the remote. If this is genuinely intended, ask the user to run it themselves."
        fi
        if has "$args" '(^|[[:space:]])(--delete|-[a-zA-Z]*d([[:space:]]|$))' \
            || has "$args" '(^|[[:space:]])[+:]'; then
            decide deny "Remote branch deletion blocked. Ask the user to run it themselves if it is intended."
        fi
    fi

    if has "$args" '^reset([[:space:]]|$)' && has "$args" '(^|[[:space:]])--hard([[:space:]]|$)'; then
        decide deny "\`git reset --hard\` blocked: it permanently discards uncommitted work in the working tree. Use \`git restore --staged\`, \`git stash push\`, or a soft/mixed reset instead, or ask the user to run it themselves."
    fi

    if has "$args" '^clean([[:space:]]|$)' \
        && has "$args" '(^|[[:space:]])-[a-zA-Z]*[fdx]' \
        && ! has "$args" '(^|[[:space:]])(-[a-zA-Z]*n([[:space:]]|$)|--dry-run)'; then
        decide deny "\`git clean\` blocked: it permanently deletes untracked files, which are not recoverable from git. Run it with --dry-run to show what it would remove, or ask the user to run it themselves."
    fi

    if has "$args" '^checkout([[:space:]]|$)'; then
        if has "$args" '(^|[[:space:]])--([[:space:]]|$)' \
            || has "$args" '(^|[[:space:]])\.([[:space:]]|$)' \
            || has "$args" '(^|[[:space:]])(--force|-[a-zA-Z]*f([[:space:]]|$))'; then
            decide deny "Destructive \`git checkout\` blocked: checking out paths (or --force) overwrites uncommitted changes in the working tree. Ask the user to run it themselves if that is intended."
        fi
    fi

    # `git restore --staged` only unstages and is safe; without it, restore
    # overwrites the working tree.
    if has "$args" '^restore([[:space:]]|$)' \
        && ! has "$args" '(^|[[:space:]])(--staged|-S([[:space:]]|$))'; then
        decide deny "\`git restore\` blocked: it discards uncommitted changes in the working tree. \`git restore --staged\` (unstage only) is allowed; otherwise ask the user to run it themselves."
    fi

    if has "$args" '^stash([[:space:]]|$)' && has "$args" '(^|[[:space:]])(drop|clear)([[:space:]]|$)'; then
        decide deny "\`git stash drop/clear\` blocked: it permanently discards stashed work. Ask the user to run it themselves."
    fi

    if has "$args" '^branch([[:space:]]|$)' \
        && has "$args" '(^|[[:space:]])(-D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)([[:space:]]|$)'; then
        decide deny "Force branch deletion blocked: -D discards unmerged commits. Use \`git branch -d\` if the branch is merged, or ask the user to run it themselves."
    fi

    if has "$args" '^reflog([[:space:]]|$)' && has "$args" '(^|[[:space:]])(expire|delete)([[:space:]]|$)'; then
        decide deny "Rewriting the reflog is blocked: it removes the safety net that makes other git mistakes recoverable."
    fi

    if has "$args" '^update-ref([[:space:]]|$)' && has "$args" '(^|[[:space:]])-d([[:space:]]|$)'; then
        decide deny "\`git update-ref -d\` blocked: deleting a ref directly can orphan commits."
    fi

    if has "$args" '^filter-branch([[:space:]]|$)'; then
        decide deny "\`git filter-branch\` blocked: it rewrites history across the whole repository. Ask the user to run it themselves."
    fi

    # ------------------------------------------------------------------- ask

    if has "$args" '^push([[:space:]]|$)' \
        && ! has "$args" '(^|[[:space:]])(--dry-run|-[a-zA-Z]*n([[:space:]]|$))'; then
        decide ask "This pushes to a remote. CLAUDE.md requires explicit permission before pushing — approving this prompt is that permission."
    fi

    if has "$args" '^commit([[:space:]]|$)' && has "$args" '(^|[[:space:]])--amend([[:space:]]|$)'; then
        decide ask "\`git commit --amend\` rewrites the previous commit. Confirm this is the intended commit to amend."
    fi
done <<< "$segments"

exit 0
