# Claude Code harness

A small, reusable Claude Code configuration: how I want Claude to work, some
workflows worth repeating, and two hooks that enforce what instructions alone
cannot.

It is deliberately minimal — one global `CLAUDE.md`, three agents, four skills,
two hooks. It is meant to grow from real usage, not from speculation about what
might be useful.

## The public/private boundary

**This repository is public.** That is the constraint everything below is shaped
around.

`~/.claude` is a live state directory: sessions, shell history, OAuth
credentials, plugin state, and the per-project memory Claude writes under
`projects/`. Almost none of it is safe to publish, and some of it Claude Code
writes on its own without asking.

So the directory is never linked as a whole. Only these known-safe paths are
installed into it:

```
~/.claude/
├── CLAUDE.md      → dotfiles/claude/CLAUDE.md      symlink
├── agents/        → dotfiles/claude/agents/        symlink
├── skills/        → dotfiles/claude/skills/        symlink
├── hooks/         → dotfiles/claude/hooks/         symlink
├── settings.json    merged from dotfiles at install time — NOT a symlink
│
├── projects/        private: per-project memory Claude writes    ← never tracked
├── sessions/        private: transcripts                         ← never tracked
├── plugins/         private: local plugin state                  ← never tracked
└── .credentials.json                                             ← never tracked

~/.claude.json       OAuth state, MCP servers, per-project trust  ← never tracked
```

Anything Claude Code creates under `~/.claude` that is not in that first group
stays outside this repository by construction, rather than by remembering to
gitignore it.

**The rule, in one line: this harness may describe how I work, never what I am
working on.** Project names, infrastructure, hostnames, domains, account or
organisation names, filesystem paths, and anything learned while working on a
private codebase do not belong in any file here. That rule is also written into
`CLAUDE.md` so Claude itself enforces it.

### Why `settings.json` is merged instead of symlinked

Everything else in the harness is written only by me, so a symlink is right —
edit the repo, it is live immediately.

`settings.json` is different: **Claude Code writes to it itself.** Toggling a
plugin, running `/config`, or the auto-mode classifier all rewrite this file.
The auto-mode block in particular records organisation name, cloud providers,
internal domains, package registries, and protected production namespaces. On a
symlink, all of that would land in a public repo automatically, with no prompt.

So the installer merges instead:

```sh
jq -s '.[0] * .[1]' ~/.claude/settings.json claude/settings.json
```

Local first, repo second — repo values win, and keys only the local install
knows about (`enabledPlugins`, `extraKnownMarketplaces`, `autoMode`) survive
untouched. The merge is idempotent and backs up the previous version.

The tradeoff: **edit `claude/settings.json` and re-run `./install.sh`.** Changes
made through `/config` land locally and are overwritten on the next run. The
same "copy, then re-run" pattern the wallbash templates use.

## Layout

```
claude/
├── CLAUDE.md            global behavioural guidance
├── settings.json        permissions + hook registration
├── agents/
│   ├── researcher.md    read-only reconnaissance (haiku)
│   ├── reviewer.md      independent review of a change
│   └── tester.md        independent validation
├── skills/
│   ├── implement/       /implement
│   ├── debug/           /debug
│   ├── review/          /review
│   └── commit/          /commit
└── hooks/
    ├── protect-git.sh        PreToolUse — blocks destructive git
    ├── test-protect-git.sh   regression tests for the above
    └── verify-task.sh        Stop — shows the resulting working tree
```

## Install

Handled by the repo's `./install.sh`, in its "Claude Code configuration"
section. Nothing separate to run. `./install.sh --no-claude` skips the section
entirely, for someone who wants the rest of the dotfiles but not this harness.

Both hooks need `jq`, which is already in `os/linux/pacman.txt` and
`os/macos/Brewfile`.

## Agents

Invoked by Claude when a task calls for one, or on request ("use the researcher
to…").

| Agent | Tools | Model | Purpose |
|-------|-------|-------|---------|
| `researcher` | `Read, Grep, Glob` | haiku | Explores the codebase and reports findings, keeping the file contents out of the main context. Has **no** tool that can modify anything — read-only is enforced by the tool list, not by instruction. |
| `reviewer` | `+ Bash` | session default | Reviews a completed change against the surrounding code. Reports findings by severity; says so plainly when there are none. |
| `tester` | `+ Bash` | session default | Finds the project's real test/build/lint commands, runs the smallest relevant set, and separates real failures from pre-existing ones. |

`researcher` uses haiku because reconnaissance is high-volume and shallow. The
other two inherit the session model, since review and failure diagnosis are
exactly where a weaker model costs more than it saves.

## Skills

| Skill | What it does |
|-------|--------------|
| `/implement` | research → plan → implement → targeted validation → diff review → summary. Scales down for trivial changes rather than forcing ceremony. |
| `/debug` | evidence → reproduce → trace → hypothesise → test → root cause → smallest fix → validate → regressions → summary. Diagnose first, modify second. |
| `/review` | Independent review of the working tree, ordered by severity. Explicitly reports a clean result rather than inventing findings. |
| `/commit` | Inspects status and the full diff, stages only what belongs to the change, proposes a message. Confirms first — except during an approved plan. Never pushes. |

All four can be invoked by typing them, and all four can be invoked by Claude
when the task fits. Their `description` fields are written as trigger conditions
("Use when the user asks to…") rather than summaries, because that field is what
matching happens on.

### Commit policy

The harness is built for one-shotting a feature: approve a plan once, then let
Claude implement and commit increments as it goes, rather than reviewing every
step.

So the confirmation in `/commit` has one exception — **an approved
implementation plan.** Inside one, Claude commits each increment without asking;
approving the plan was that permission. Outside one, it asks. `/implement` step 7
and the "Committing during an approved plan" section of `CLAUDE.md` carry the
same rule, so it holds whether the workflow is entered through the skill or not.

Two things do not relax, and they are what make delegating commits safe:

- **Staging is explicit, by path.** Anything already modified when the work
  began stays out of every commit. No `git add -A` on a tree that started dirty.
- **Never merge, and never push the default branch.** Pushing a working branch
  and opening or listing PRs are allowed without a prompt (`git push`,
  `gh pr create`, `gh pr list` in `allow`). `gh pr merge` stays in `ask`, and
  `protect-git.sh` asks before any push naming `main`, `master` or another
  protected branch, or naming no branch at all. Force and delete pushes are
  denied outright.

`git commit` is in `allow` so increments do not each raise a prompt.
`git commit --amend` stays in `ask`, and the hook independently returns `ask`
for it, so the broader allow cannot widen into history rewriting.

## Hooks

### `protect-git.sh` — PreToolUse, matcher `Bash`

Reads the command from the tool call as JSON and decides. Permission rules in
`settings.json` cover similar ground, but they match a command *prefix*, so a
chained command slips past them. This hook splits on shell separators and judges
each command on its own, and it strips `sudo`, `env FOO=bar`, and git's global
options (`-C`, `-c`, `--git-dir`) before matching.

The split is **quote-aware**, which is not cosmetic: a separator inside quotes
does not begin a new command. Without that, a JSON payload, a grep pattern, or a
line of documentation that merely *mentions* a destructive git command produces
a phantom segment starting with `git` and gets blocked — which makes writing
about git impossible. `test-protect-git.sh` covers this case; it caught it
immediately in practice.

**Denied** — Claude cannot run these at all and is told to ask me:

| | why |
|-|-----|
| `push --force`, `-f`, `--force-with-lease` | rewrites published history |
| `push --delete`, `push origin :branch` | deletes a remote branch |
| `reset --hard` | discards uncommitted work |
| `clean -f/-d/-x` | deletes untracked files, unrecoverable |
| `checkout -- <path>`, `checkout .`, `checkout -f` | overwrites the working tree |
| `restore` without `--staged` | discards working-tree changes |
| `stash drop`, `stash clear` | discards stashed work |
| `branch -D` | discards unmerged commits |
| `reflog expire/delete`, `update-ref -d`, `filter-branch` | destroys the recovery path |

**Asked** — I get a prompt, and approving it *is* the explicit permission
`CLAUDE.md` requires:

- `git push` naming a protected branch — `main`, `master`, `trunk`, `develop`,
  `release`, `production`, `HEAD` and similar — anywhere in its refspecs
- `git push` naming no branch (`git push`, `git push origin`, `--all`,
  `--mirror`), since its target depends on upstream config the hook cannot see
- `git commit --amend`

A push naming only ordinary branches gets **no opinion** from the hook, and the
`allow` rule in `settings.json` lets it through. The hook never returns `allow`:
that approves the entire command line, so `git push origin x && <anything>`
would skip the prompt for `<anything>` too. `--dry-run` passes through
untouched.

**Untouched**: `status`, `diff`, `log`, `show`, `blame`, `add`, `commit`,
`branch -d`, `stash push/list`, `fetch`, `pull`, `rebase`, `merge`,
`restore --staged`, `checkout <branch>`, `checkout -b`, and everything
`worktree` — so worktree workflows are unaffected.

It fails open if `jq` is missing. That is deliberate: the `ask` rules in
`settings.json` are the second layer, so a machine without `jq` is degraded
rather than unprotected.

### `verify-task.sh` — Stop

Advisory only. It never blocks and never fails a turn.

A shell script cannot judge whether Claude actually verified its work — that is
semantic. What it can do is make the resulting state visible, so "done" does not
have to be taken on trust. On every stop with a dirty working tree it prints the
changed paths and a diff stat.

It respects `stop_hook_active`, so it cannot loop.

Deliberately **not** a quality gate: no `decision: block`, no test running, no
heuristics about whether validation should have happened. Those nag, or loop, or
both. The behavioural half of this requirement — inspect the diff before
claiming completion — lives in `CLAUDE.md` and the skills, which is the right
place for a judgement call. If real usage shows a need for enforcement, this
file is where it goes.

## Permissions

Three lists in `settings.json`:

- **`allow`** — routine local development runs without prompting: git
  inspection, `git add`, `git commit`, `git fetch`, search tools, and the usual
  build/test/lint/type-check commands for Node, .NET, Java, Python, Go, and
  Rust.
- **`ask`** — anything reaching a remote or rewriting history: `git push`,
  `git commit --amend`, `gh pr create/merge`, `gh release`, `npm publish`,
  `docker push`.
- **`deny`** — secrets. `.env` files, key material, cloud and cluster
  credentials, Terraform state, service-account JSON, `~/.ssh`, `~/.aws`,
  `~/.claude.json`. Denied paths are excluded from search as well as from
  reading, so they do not leak into context during exploration.

`dangerously-skip-permissions` is not used, and should not be.

Two things worth knowing:

- **`cat` and friends are deliberately not in `allow`.** The `deny` list is
  scoped to the `Read` tool, so allowing `Bash(cat:*)` would route straight
  around it. Claude should read files with `Read`, where the deny rules apply.
  A shell command can still read a secret if I approve that specific prompt —
  prefix rules cannot close that hole, and closing it properly means extending
  `protect-git.sh` into a general command filter. Not worth it yet.
- **`Read(**/.env.*)` also blocks `.env.example`.** Safety over convenience. If
  that becomes annoying, replace the wildcard with the specific variants —
  `deny` always beats `allow`, so it cannot be allow-listed back.

The `allow` list is broad by design (`Bash(npm run:*)` covers `npm run deploy`).
Trim it if that ever feels too loose.

## Worktrees

Claude Code has this built in. Nothing custom here.

```sh
claude -w issue-123          # new worktree + session
claude -w issue-123 --tmux   # and a tmux session for it
```

Worktrees land in `<project>/.claude/worktrees` by default. Two things follow
from that:

- Add `.claude/worktrees/` to the **project's** `.gitignore`, not this repo's.
- `protect-git.sh` leaves every `git worktree` subcommand alone, so creating and
  removing worktrees is never blocked.

`claude agents`, `claude attach <id>`, and `claude rm <id>` manage background
sessions and clean up their worktrees when it is safe to do so.

## Project configuration

The global harness is behaviour only. Project knowledge lives in the project:

| Path | Scope | Committed? |
|------|-------|-----------|
| `CLAUDE.md` | project instructions for everyone | yes |
| `CLAUDE.local.md` | my own notes for this project | no |
| `.claude/rules/` | focused rule files | yes |
| `.claude/settings.json` | team permissions and hooks | yes |
| `.claude/settings.local.json` | my overrides | no |

Settings cascade **user → project → project-local → managed policy**, with later
sources winning. There is no user-level `settings.local.json`; user scope is the
single `~/.claude/settings.json` this repo merges into.

Project `CLAUDE.md` files are additive — they layer on top of the global one
rather than replacing it. So a project file should carry only what is specific
to that project: architecture, commands, conventions. Anything that is really
about how I work belongs here instead.

## MCP

Nothing configured. When that changes:

- **Personal servers, credentials, private endpoints** → `~/.claude.json` via
  `claude mcp add`. User scope, never tracked here.
- **Servers safe for a whole team** → `.mcp.json` in the project, committed
  there.

Neither belongs in this repository. If a genuinely generic, credential-free
server is ever worth syncing, it can go in `claude/settings.json` under
`mcpServers` — but the default assumption is private.

## Adding things

**A skill** — create `claude/skills/<name>/SKILL.md` with frontmatter:

```yaml
---
name: <name>
description: <when to use it — this is what Claude matches on>
argument-hint: [optional]
---
```

The directory name is the slash command. It is live immediately, since
`skills/` is symlinked.

**An agent** — create `claude/agents/<name>.md`:

```yaml
---
name: <name>
description: <when to invoke it>
tools: Read, Grep, Glob
model: haiku
---
```

Omit `model` to inherit the session's. Omit `tools` to grant everything —
usually the wrong default; listing tools is how read-only is actually enforced.
Also live immediately.

**A permission or hook** — edit `claude/settings.json`, then re-run
`./install.sh`. This is the one file that does not take effect on save.

## Verifying

```sh
claude doctor                                    # config health
ls -la ~/.claude/{CLAUDE.md,agents,skills,hooks} # should be symlinks
ls -la ~/.claude/settings.json                   # should NOT be a symlink
```

To exercise a hook by hand:

```sh
jq -n '{tool_name:"Bash",tool_input:{command:"git reset --hard"}}' \
  | ~/.claude/hooks/protect-git.sh
```

Empty output means "no opinion". A decision comes back as JSON.

`claude --safe-mode` starts with all of this disabled, which is the fastest way
to tell whether a problem is the harness or Claude Code itself.
