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
#   deny   Claude cannot run it at all, and is told to ask me to run it myself.
#   ask    I get a prompt, which is where I confirm a push CLAUDE.md has not
#          already authorised — including one to the default branch, which
#          CLAUDE.md rules out and only I can decide to make anyway.
#   allow  Only for a push whose branches *all* match
#          CLAUDE_GIT_PUSH_ALLOW_PREFIX, which is how an unattended loop pushes
#          its own feature branches.

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

# Every branch a push would write to, one per line, or nothing when the command
# does not name any explicitly.
#
# This only ever widens `ask` into `allow`, so "cannot tell" must return nothing
# and let the prompt happen. It deliberately does not consult the repository to
# resolve a bare `git push` -- that would need the hook's cwd to be the right
# worktree, and guessing wrong means silently pushing an unintended branch.
#
# *Every* refspec is returned, not just the last one. `push origin main x`
# writes both, so judging it on `x` alone would wave the push to main straight
# through -- which is the one thing the caller must never do.
#
#   push -u origin kseeman123/x       ->   kseeman123/x
#   push origin HEAD:feature/x        ->   feature/x
#   push origin main kseeman123/x     ->   main, kseeman123/x
#   push origin                       ->   (nothing -- current branch, unknown)
push_targets() {
    local -a words
    local w r remote_seen=0 skip_value=0

    read -r -a words <<< "$1"

    # Skip "push" itself. The ${arr[@]+...} guard keeps this safe under `set -u`
    # on bash 3.2.
    for w in ${words[@]+"${words[@]:1}"}; do
        # Options taking a separate value, whose value must not be mistaken for
        # a remote or a refspec.
        if ((skip_value)); then
            skip_value=0
            continue
        fi

        case "$w" in
            -o|--push-option|--repo|--receive-pack|--exec) skip_value=1; continue ;;
            -*) continue ;;
        esac

        # The first bare word is the remote; everything after it is a refspec.
        if ((remote_seen == 0)); then
            remote_seen=1
            continue
        fi

        r="$w"
        r="${r#+}"              # force marker: +feature/x -> feature/x
        r="${r##*:}"            # a refspec writes to its right-hand side
        r="${r#refs/heads/}"    # fully-qualified ref -> plain branch name

        [[ -n "$r" ]] && printf '%s\n' "$r"
    done
}

# Branches never eligible for the unattended allowlist, whatever prefix is set.
# Matched exactly, against the name push_targets has already normalised, so
# `refs/heads/main` is caught but a feature branch called `main-fix` is not.
#
# This is a backstop for a carelessly broad prefix, not the primary defence --
# it cannot know a given repository's actual default branch, so it covers the
# names that are conventionally protected and relies on the prefix being
# specific for anything else.
is_protected_branch() {
    case "$1" in
        main|master|trunk|default|develop|development|release|stable|production|HEAD)
            return 0 ;;
    esac

    return 1
}

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

        # Unattended opt-in. When CLAUDE_GIT_PUSH_ALLOW_PREFIX names a branch
        # prefix, pushing a matching branch skips the prompt -- which is what
        # lets an agent loop run without someone at the keyboard.
        #
        # An environment variable rather than a config file, deliberately: the
        # relaxation lives exactly as long as the session that exports it, and
        # cannot be committed somewhere and quietly outlive its reason. Force
        # and delete pushes never reach here -- they are denied above.
        allow_prefix="${CLAUDE_GIT_PUSH_ALLOW_PREFIX:-}"
        if [[ -n "$allow_prefix" && "$allow_prefix" != "*" && "$allow_prefix" != "/" ]]; then
            targets="$(push_targets "$args")"

            # Every named branch must clear the bar, not just one of them, and
            # naming none at all is "cannot tell" rather than consent.
            if [[ -n "$targets" ]]; then
                allowed=1
                names=""

                while IFS= read -r target; do
                    if is_protected_branch "$target"; then
                        allowed=0
                        break
                    fi

                    case "$target" in
                        "$allow_prefix"*) names="${names:+$names, }$target" ;;
                        *) allowed=0; break ;;
                    esac
                done <<< "$targets"

                if ((allowed)); then
                    decide allow "Pushing $names, which matches CLAUDE_GIT_PUSH_ALLOW_PREFIX ('$allow_prefix')."
                fi
            fi
        fi

        decide ask "This pushes to a remote. CLAUDE.md allows pushing a working branch but never the default branch, and never merging — approving this prompt confirms this push."
    fi

    if has "$args" '^commit([[:space:]]|$)' && has "$args" '(^|[[:space:]])--amend([[:space:]]|$)'; then
        decide ask "\`git commit --amend\` rewrites the previous commit. Confirm this is the intended commit to amend."
    fi
done <<< "$segments"

exit 0
