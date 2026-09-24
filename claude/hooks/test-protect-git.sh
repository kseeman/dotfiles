#!/usr/bin/env bash
#
# Regression tests for protect-git.sh.
#
# Run directly:  ./claude/hooks/test-protect-git.sh
#
# The "quoted text" block is the one that matters most. A naive split on shell
# separators blocks any command that merely quotes a destructive git string —
# a grep pattern, a JSON payload, a line of documentation — which makes writing
# about git impossible. That regressed once; these cases keep it fixed.

set -uo pipefail

HOOK="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/protect-git.sh}"

pass=0
fail=0

t() {
    local cmd="$1" expect="$2" out got

    out="$(jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | "$HOOK")"

    if [[ -z "$out" ]]; then
        got=none
    else
        got="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null || echo PARSE_ERROR)"
    fi

    if [[ "$got" == "$expect" ]]; then
        pass=$((pass + 1))
        printf 'ok    %-56s -> %s\n' "$cmd" "$got"
    else
        fail=$((fail + 1))
        printf 'FAIL  %-56s -> %s (want %s)\n' "$cmd" "$got" "$expect"
    fi
}

echo "--- routine development: untouched ---"
for c in \
    'git status' 'git diff' 'git diff --staged' 'git log --oneline -20' \
    'git show HEAD~1' 'git blame src/a.ts' 'git branch -a' 'git branch -d feature' \
    'git add -A' 'git commit -m "fix: thing"' 'git stash push -m wip' 'git stash list' \
    'git fetch origin' 'git pull --rebase' 'git rebase main' 'git merge feature' \
    'git restore --staged src/a.ts' 'git checkout -b feature/new' 'git checkout main' \
    'git worktree add ../wt issue-1' 'git worktree remove ../wt' 'git worktree list' \
    'git -C /repo status' 'npm test' 'make build' 'dotnet test'
do t "$c" none; done

echo
echo "--- dry runs: untouched ---"
t 'git push --dry-run' none
t 'git clean -fdn' none

echo
echo "--- quoted text that only mentions git: must not trip ---"
t 'rg "git push" src/' none
t "grep -r 'git reset --hard' docs/" none
t 'echo "never run git clean -fdx here"' none
t "jq -n '{c:\"cd /r && git reset --hard x\"}'" none
t 'printf "%s" "git push --force"' none
t "git commit -m 'do not git push --force'" none

echo
echo "--- ask ---"
for c in \
    'git push' 'git push origin main' 'cd /tmp/repo && git push' \
    'git -C /tmp/repo push origin main' 'sudo git push' \
    'git -c user.name=x push' 'git commit --amend --no-edit'
do t "$c" ask; done

echo
echo "--- deny ---"
for c in \
    'git push --force' 'git push -f origin main' 'git push --force-with-lease' \
    'git push origin --delete feature' 'git push origin :feature' \
    'git reset --hard' 'git reset --hard HEAD~3' 'cd repo && git reset --hard origin/main' \
    'git clean -fd' 'git clean -fdx' 'git clean -xdf' \
    'git checkout -- .' 'git checkout .' 'git checkout -f main' \
    'git restore src/a.ts' 'git restore .' \
    'git stash drop' 'git stash clear' 'git branch -D feature' \
    'git reflog expire --expire=now --all' 'git update-ref -d refs/heads/x' \
    'git filter-branch --tree-filter x HEAD' 'sudo git reset --hard' \
    'git -C /repo push --force' 'echo hi; git clean -fdx' 'git status && git reset --hard'
do t "$c" deny; done

echo
echo "--- push policy ---"

# A working branch pushes without a prompt: the hook stays silent and
# settings.json's allow rule applies. Never `allow` -- that would approve the
# rest of the command line too.
t 'git push origin feature/x' none
t 'git push -u origin feature/x' none
t 'git push origin HEAD:feature/x' none
t 'git push origin refs/heads/feature/x' none
t 'git push origin a b' none
t 'cd /tmp/repo && git push -u origin feature/x' none
t 'git push -o ci.skip origin feature/x' none
t 'git push origin main-fix' none
t 'git push origin feature/x && rm -rf build' none

# A protected branch asks, wherever it appears in the refspecs.
t 'git push origin main' ask
t 'git push origin master' ask
t 'git push origin HEAD:refs/heads/main' ask
t 'git push origin trunk' ask
t 'git push origin production' ask
t 'git push origin develop' ask
t 'git push origin HEAD' ask
t 'git push origin main feature/x' ask
t 'git push origin feature/x main' ask
t 'git push -u origin master feature/x' ask
t 'git push origin feature/x && git push origin main' ask

# No branch named: the target depends on config the hook cannot see.
t 'git push' ask
t 'git push origin' ask
t 'git push --all origin' ask
t 'git push --mirror origin' ask

# Force and delete stay denied on any branch.
t 'git push --force origin feature/x' deny
t 'git push -f origin feature/x' deny
t 'git push origin :feature/x' deny
t 'git push origin --delete feature/x' deny

echo
echo "pass=$pass fail=$fail"

[[ $fail -eq 0 ]]
