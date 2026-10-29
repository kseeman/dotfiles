# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal dotfiles repository covering Neovim, zsh, and terminal configuration across macOS and Linux. The Linux Hyprland desktop is a separate repository, `kseeman/desktop`, installed on top of this one. The Neovim configuration is built on NvChad v2.5 and features a custom multi-profile system that loads different plugin sets and configurations based on the development environment (default, .NET, Java, Python, or Node).

## Change workflow

Desktop and rice work happens in `kseeman/desktop`, which has its own
PR-based workflow because a desktop can be tried in a nested compositor before
it lands. Nothing in this repo can be tried that way.

Isolate the work in a worktree, land it on `main` locally, stop for testing,
push once it passes. **No pull request**, because nothing here can be tried
until it is on `main` — a PR would add a round trip before the only test that
counts.

The order is forced by how the repo is installed. `~/.dotfiles` symlinks to this
checkout and everything else resolves through it — `~/.zshrc`,
`~/.config/nvim`, `~/.local/bin/tmux-sessionizer`, the tmux config. **A change
is live only once it is on `main` in this checkout.** Work sitting on a branch
or in a worktree cannot be tested by using it, which is why the merge comes
before the push rather than after.

1. **Fetch before creating the worktree.** A new worktree branches from
   `origin/main` as the local ref last saw it, so a stale ref bases the work on
   an old commit and turns step 3 into a rebase.
2. **Work in the worktree**, committing meaningful increments.
3. **Fast-forward `main` to the branch** once validation passes. This step is
   pre-authorised — it is the point of the workflow and does not need to be
   asked for each time. It is also where authority ends.
4. **Say the work is on `main` and ready to try, then stop.** Testing is the
   user's, and it happens here, against the live symlinks.
5. **Push `main`** once the user confirms. This is the step that reaches the
   other machines, and pushing to the default branch is expected here —
   it overrides the global rule against it. It still never happens in the same
   breath as the merge.
6. **Remove the worktree and branch.**

Keep step 3 a real fast-forward:

```sh
git fetch origin main
git -C .claude/worktrees/<name> rebase origin/main   # only if main moved
git merge --ff-only <branch>
```

Rebase from *inside* the worktree — the branch is checked out there, so a
`git rebase` run from this checkout fails. A cherry-pick reaches the same
content but gives the commit a new SHA, after which `git branch -d` refuses the
source branch as unmerged and only `git branch -D` removes it — which
`protect-git.sh` blocks by design, leaving a branch that has to be deleted by
hand.

## Cross-Platform Structure

The repo supports macOS (Apple Silicon) and Arch-based Linux from one tree. Shared configuration lives at the top level; anything that genuinely differs per platform lives under `os/<os>/`.

```
lib/os.sh              OS detection, shared by install.sh (bash) and zsh
lib/install.sh         Installer helpers (bash): linking, the link scan, manifests
install.sh             Shared install steps; dispatches to the OS installer
zsh/                   Shared shell configuration
kitty/ fastfetch/      Shared config sources (linked per-OS, see below)
tmux/                  Shared tmux config; OS fragment in os/<os>/tmux.conf
nvim/                  Shared; already cross-platform via profile-manager.lua
os/macos/              Brewfile, install.sh, zsh/{exports,aliases}.zsh
os/linux/              pacman.txt, aur.txt, install.sh, zsh/{exports,aliases}.zsh
```

### Detection

`lib/os.sh` is the single source of truth and must stay **POSIX sh** — it is sourced by both bash (`install.sh`) and zsh (`zsh/bootstrap.zsh`). It exports:

- `DOTFILES_OS` — `macos` or `linux`
- `DOTFILES_DISTRO` — normalized to a *family* (`arch`, `debian`, `fedora`), so derivatives resolve to the package manager they actually use. CachyOS reports `arch`.

`dotfiles_detect_distro()` reads `/etc/os-release` in a subshell on purpose; sourcing it directly would leak `ID`/`NAME`/`VERSION` into every interactive shell.

### Shell load order

`zsh/init.zsh` sources `os/$DOTFILES_OS/zsh/{exports,aliases,functions}.zsh` **before** the shared files.

OS files own what differs — package-manager paths, `NVM_SH`, `JAVA_HOME`, the `ls` color flag — and shared files read those. **A shared file must never redefine something an OS file owns.** That one rule keeps load order significant in a single direction; violating it makes the ordering load-bearing in both, which is how these setups become unpredictable.

### Adding a package

Add it to **both** `os/macos/Brewfile` and `os/linux/pacman.txt` — they are parallel manifests and drift silently otherwise. AUR-only packages go in `os/linux/aur.txt` (installed via `paru`, falling back to `yay`).

### NVM

Deliberately split: Node versions live in `$NVM_DIR` (`~/.nvm`) on both platforms, but `nvm.sh` itself is at `/opt/homebrew/opt/nvm/nvm.sh` on macOS and `/usr/share/nvm/nvm.sh` on Arch. The OS files set `NVM_SH`/`NVM_COMPLETION`; shared code just sources whatever they point at. `nvm` is a shell function, not a binary, so `command -v nvm` cannot be used to check for it.

### Which configs get linked is per-OS

`install.sh` links what is universally shared (`~/.dotfiles`, `~/.zshrc`, `~/.config/nvim` — `nvim/` is already cross-platform via `profile-manager.lua`). Each OS installer may define an `os_link_configs()` hook, called after the `~/.dotfiles` symlink exists, for everything else.

**Kitty and Fastfetch are linked everywhere.** They used to be skipped on Linux
while HyDE was present, to leave the existing desktop untouched — and that skip is exactly what made them the last two things
still themed by HyDE, so removing it would have taken the terminal's colours and
the shell banner's logo with it. Owning them is what makes that removal a
non-event.

Taking them over is safe because `link_config` moves whatever is there to
`<name>.pre-dotfiles` first, so HyDE's generated files are kept rather than
overwritten, and neither program is session-specific: one terminal config serves
both sessions while both existed. HyDE's leftover `hyde.conf` was simply never
included by ours, and went with the rest of it.

The two configs differ from HyDE's in one visible way: its Fastfetch logo came
from a theme-aware `fastfetch.sh logo` call reading images out of
`~/.config/fastfetch/logo/`, while this repo's uses `"type": "builtin"` — the
distro logo, with no external dependency. `run_fastfetch` in
`zsh/functions.zsh` points at `~/.config/fastfetch/config.jsonc` either way.

### tmux

`tmux/tmux.conf` is shared and linked to `~/.config/tmux/tmux.conf` by the shared installer. The only genuinely platform-specific part is clipboard integration, which lives in `os/<os>/tmux.conf`, is linked to `~/.config/tmux/os.conf`, and is pulled in by `source-file -q` at the end of the shared config. The `-q` keeps `tmux.conf` usable standalone.

This inverts the usual pattern: rather than the OS file loading first, tmux sources it **last**, because a `bind` simply replaces any earlier binding. So `y` in copy mode is bound to `wl-copy` on Linux and `pbcopy` on macOS, overriding nothing else.

The prefix is deliberately left at the default `C-b` — the config is written for someone learning tmux, where matching every tutorial and working unchanged over SSH matters more than ergonomics.

Two settings are load-bearing for Neovim and should not be removed: `escape-time 10` (the 500ms default makes `Esc` feel broken in nvim) and `focus-events on` (nvim's autoread). Colors are left to the terminal palette rather than hardcoded, so the status bar follows whatever rice is active.

In-tmux help replaces two defaults: `prefix + ?` opens `tmux/cheatsheet.txt` in a `display-popup`, and `prefix + /` pipes `list-keys -N` into fzf. `list-keys -N` shows **only bindings with a note**, so every custom `bind` carries `-N "…"` — a binding added without one is silently missing from the search. The cheatsheet is hand-written and read from `~/.dotfiles` at runtime, so it needs no linking, but it must be updated by hand when a binding changes.

Validate config changes without touching a live session by using a separate socket:

```sh
tmux -L cfgtest -f ~/.config/tmux/tmux.conf new-session -d && \
  tmux -L cfgtest list-keys -T prefix; tmux -L cfgtest kill-server
```

#### Plugins

Managed by tpm, cloned by `install.sh` into `~/.config/tmux/plugins/` — a real directory outside the repo, so nothing needs gitignoring. `tmux-resurrect` saves/restores sessions, `tmux-continuum` drives it on a 15-minute timer and restores on server start.

`TMUX_PLUGIN_MANAGER_PATH` is deliberately **not** set. tpm derives `<xdg>/tmux/plugins` itself when it finds `tmux.conf` under XDG, and setting it in the config would actively break things — tmux does not expand `~` in `set-environment`, so the literal tilde path fails to resolve.

The `run '…/tpm'` line must stay last; tpm only sees plugins declared above it.

Installing plugins needs a server with the config loaded. From outside a session:

```sh
tmux -L boot -f ~/.config/tmux/tmux.conf new-session -d
tmux -L boot run-shell '~/.config/tmux/plugins/tpm/bin/install_plugins'
tmux -L boot kill-server
```

#### Session management

`tmux/scripts/tmux-sessionizer` fuzzy-finds a project under the `SEARCH_PATHS` array (currently `~/Repos` and `~/dotfiles`) and attaches to a session named after it, creating it if needed. Bound to `prefix + f` and linked into `~/.local/bin`, so it works from a plain shell too. It handles being run both inside tmux (`switch-client`) and outside (`attach-session`), and strips dots from session names since tmux treats them as host/port separators.

**It is the single definition of what a project is**, and everything else routes through it rather than keeping a second list: the `dev` shell function (`zsh/functions.zsh`), `prefix + f`, and Neovim's dashboard "Projects" action via `nvim/lua/configs/projects.lua`. A non-directory argument is treated as a query rather than a path, and `fzf --select-1` takes an unambiguous match outright, which is what makes `dev dotfiles` skip the menu. `dev -` switches back to the last session without opening the picker at all.

The script has several entry points, and only one of them is a contract:

- **`--list`** prints plain paths and is read by Neovim's dashboard. Keep it stable — it is what stops nvim from reimplementing the roots.
- **`--fzf-list`**, **`--preview`** and **`--kill`** exist because fzf re-invokes the script for its preview pane and its `ctrl-x` binding. They are not meant to be typed, and `$0` is what lets fzf find the script again (it is runnable both as the `~/.local/bin` symlink and as the repo path tmux uses).

Picker details worth knowing before editing it:

- Lines are `<display><TAB><path>`; fzf shows and searches field 1 via `--with-nth` and passes field 2 to the preview and kill bindings, so **the path is never parsed back out of the display text**. The parent directory is shown because a basename alone is ambiguous once several roots are configured — `~/repos/personal/dotfiles` and `~/Repos/dotfiles` are two projects with one name.
- `● / ○` mark whether a project already has a session, and live ones sort first. Deliberately glyphs rather than colours, so the list follows the terminal palette like everything else here.
- **The `<55(…)` threshold in `--preview-window` is the width of the *preview window*, not the terminal.** It moves the preview above the list in a narrow pane; written as a terminal width it fires far too early (`<100` triggers at 130 columns, because the preview would be 71).
- `bat` renders the README with `--theme=ansi`. Its default theme is hardcoded truecolor and would ignore the active tokyonight/rice palette.
- `ctrl-/` is bound twice (`ctrl-/` and `ctrl-_`) because terminals disagree about what that key sends.

One bash gotcha the script comments but is easy to reintroduce: `${path/#$HOME/\~}` keeps the **backslash** in the result, because the replacement half of `${var/pat/repl}` is not re-parsed. The tilde goes through a `TILDE` variable instead.

A newly created session gets an `editor` window with nvim started in it and a `shell` window. Two details are deliberate:

- **nvim is typed into the window's shell with `send-keys`, not run as the window's command.** As the window command, quitting nvim would close the window; this way it leaves a usable shell.
- **The window is named with `-n`,** which turns `automatic-rename` off for it, so `editor` does not become `nvim` the moment the editor starts.

Per-project layouts are one hook and no manifest format: an executable `~/.config/dotfiles/tmux/layouts/<session-name>`, run with the session name, project directory and pinned profile after the session exists with its single `editor` window. It owns the layout from there. This mirrors `~/.config/dotfiles/tmux/sessionizer-paths` — machine- and project-specific things live outside this public repo.

A project pins which nvim profile its session opens with via a one-line `~/.config/dotfiles/tmux/profiles/<session-name>` containing the profile name. Three things make this work the way it does:

- It is delivered as `tmux new-session -e NVIM_PROFILE=…`, so it lands in the **session environment** and every pane inherits it. Prefixing the `nvim` command instead would only cover the `editor` window, and `nvim` typed in the shell window would get the wrong profile.
- `NVIM_PROFILE` already outranks the persisted profile in `get_current_profile()`, so a pinned project beats whatever `:ProfileSwitch` last chose globally, with no change to the profile system.
- **It is applied at session creation only.** Changing the pin means killing the session and reopening — there is no mechanism to retrofit an environment onto a running session's existing panes, and silently applying it to new panes only would be worse than not applying it at all.

The profile name is deliberately **not** validated in the script: `profile-manager.lua` already warns and falls back to `default` for an unknown one, and validating here would mean a second copy of the profile list to keep in step.

**The layout only runs on creation.** Attaching to a session that already exists must never disturb it; that session *is* the workspace.

#### Colours come from the desktop palette (Linux)

The desktop repo renders `$XDG_CACHE_HOME/dotfiles/theme/tmux.conf` from its
palette, and `tmux.conf` sources it at the end, so the status bar follows
whichever rice is active. Without the desktop the file is absent, `-q` skips
it, and the plain styles stand.

**Styles only.** Formats and layout stay in `tmux.conf`, which is what lets the
bar be recoloured without touching its structure. That split is inherited from
the wallbash template it replaces and is worth keeping.

**Two source lines, because tmux cannot express one.** It expands `$VAR` in a
path but not `${VAR:-default}`, and an unset variable with `-q` resolves to a
path that silently does not exist. So the default location is tried first and
the XDG one second, where it wins if that variable points elsewhere. When both
name the same file it is sourced twice, which costs nothing — every line in it
is a `set`.

It replaced a wallbash template HyDE regenerated. That template was sourced with
`-q`, so removing HyDE would have taken the colours away *silently* — which is
why tmux was decoupled before the removal rather than during it.

### Claude Code harness

`claude/` is a self-contained Claude Code configuration installed into
`~/.claude` by the shared installer. It is shared across platforms — nothing in
it is OS-specific, so there is no `os/` counterpart. `--no-claude` skips the
whole step; nothing else in the install depends on it, so keep it that way.

**This repo is public, and that constraint shapes the whole design.**
`~/.claude` is a live state directory holding session transcripts,
`.credentials.json`, plugin state, and the per-project memory Claude writes
under `projects/`. It is therefore **never linked as a whole**. Only four known-
safe paths are symlinked in (`CLAUDE.md`, `agents/`, `skills/`, `hooks/`), so
anything Claude Code creates later stays outside the repo by construction rather
than by remembering to gitignore it.

The invariant, stated in `claude/CLAUDE.md` so Claude enforces it too: **this
harness describes how the user works, never what they are working on.** No
project or product names, hostnames, domains, organisation names, infrastructure
details, or filesystem paths belong in any file under `claude/`. Project
knowledge goes in that project's own `CLAUDE.md` / `.claude/`, which this repo
does not track.

**`settings.json` is merged, not symlinked** — the one asymmetry, and the reason
`merge_json_config()` exists in `install.sh`. Every other file in the harness is
written only by the user, so a symlink is right. `settings.json` is also written
by *Claude Code itself*: plugin toggles, `/config`, and the auto-mode classifier
all rewrite it, and the `autoMode.environment` block it maintains records
organisation name, cloud providers, internal domains, and protected production
namespaces. Through a symlink that would land in a public repo automatically,
unprompted.

So the installer runs `jq -s '.[0] * .[1]' <local> <repo>`: repo values win,
local-only keys (`enabledPlugins`, `extraKnownMarketplaces`, `autoMode`) survive,
and the result is idempotent. The consequence to remember: **editing
`claude/settings.json` requires re-running `./install.sh`.** Everything else in
`claude/` is live on save.

The function also replaces the target if it finds a symlink there, since a
symlink would make the merge write into the repo — the exact failure it exists
to prevent.

Two details that are load-bearing:

- `claude/agents/researcher.md` declares `tools: Read, Grep, Glob` with no
  `Bash`. Read-only is enforced by the tool list, not by prompt instruction.
  Adding `Bash` to it silently removes that guarantee.
- Both hooks require `jq` (already in both package manifests) and must exit 0
  on every path. `protect-git.sh` fails open when `jq` is absent, because the
  `ask` rules in `settings.json` are the second layer; `verify-task.sh` honours
  `stop_hook_active`, without which a `Stop` hook loops.

`protect-git.sh` splits commands on shell separators and strips `sudo`,
`env FOO=bar`, and git's global options (`-C`, `-c`, `--git-dir`) before
matching — that is what makes a chained destructive command catchable, which a
prefix-matching permission rule cannot do. **The split must stay quote-aware:** a
separator inside quotes does not start a new command, and without that rule any
command merely quoting a destructive git string (a grep pattern, a JSON payload,
this very documentation) invents a segment beginning with `git` and is refused.

Every `git worktree` subcommand is deliberately left alone, so `claude -w <name>`
workflows are never blocked.

See `claude/README.md` for the agent/skill/hook reference and how to add more.

### Theme cache (written by the desktop repo)

The Hyprland desktop lives in its own repository, `kseeman/desktop`, installed
on top of this one on the Linux machine only. It themes tmux, kitty and nvim by
writing `$XDG_CACHE_HOME/dotfiles/theme/`; they read it when it is there and
keep their own colours when it is not, which is what every other machine sees.

**That directory is the whole interface.** Nothing here names a file in the
desktop repo, and nothing should start to — the dependency points one way, and
a Mac carrying none of the desktop is what the split was for. The other half is
`lib/install.sh`, which the desktop's installer sources.

**kitty takes the desktop's chrome; its ANSI colours deliberately do not.**
`kitty.conf` includes the generated file *after* its own `theme.conf`, so the
chrome — background, foreground, cursor, selection, borders, tabs — follows the
rice while the sixteen ANSI colours stay hand-picked. Deriving those from the
desktop's palette would give three shades of one violet where red, green and yellow should
be, and terminal output that cannot be told apart: ANSI colours need to be
distinguishable from *each other*, which is a different job from matching the
desktop.

A missing include is a warning kitty ignores, so macOS keeps `theme.conf` alone.

**nvim splits the same way, for the same reason.** `nvim/lua/themes/rice.lua` is
a base46 theme whose *structure* — backgrounds, the surface ramp, line numbers,
separators, selection, comments, the accent on a popup selection and a float
border — comes from the rice, while the syntax hues stay tokyonight's. base46
resolves `themes.<name>` from this config before its own, so the name in
`chadrc.lua` is just the file.

Three things about it are load-bearing:

- **The theme is tracked and carries no desktop colour.** Values arrive through
  `$XDG_CACHE_HOME/dotfiles/theme/nvim.lua`, rendered by the desktop.
  Unlike kitty's output this one follows `XDG_CACHE_HOME`, because nvim can
  resolve the base directories itself.
- **It falls back to tokyonight's own structural values** when there is no
  generated palette — a Mac, a fresh machine, a rice switch caught half-written.
  Verified against a missing file and a truncated one; both give the colours
  this config had before, so the failure is invisible rather than broken.
- **base46 compiles themes to bytecode and `init.lua` only loads the result**,
  so a palette change reaches nvim through a recompile rather than by being
  read. `init.lua` stats the generated palette against the compiled cache and
  recompiles when it is newer — one stat per start, and measured not to
  recompile when nothing changed. On the desktop a palette edit lands at the
  next login; here it lands at the next nvim start.

**`transparency = true` in `chadrc.lua` blanks most backgrounds**, so several of
the mapped names have no visible effect while it is on: `Normal`, `CursorLine`,
`Pmenu` and the statusline all come back unset. What actually changes with the
rice is the selection, comments, line numbers, window separators, float and
Telescope borders, and the popup selection. Turning transparency off is what
would make `statusline_bg` and the surface ramp show.

**One include line, unlike tmux's two — and that difference is not cosmetic.**
kitty treats a file included twice as a configuration *error* and puts a dialog
in front of every new terminal, so the trick tmux allows (name both the default
and the XDG location, let the later win) is unavailable. It also cannot express
`${VAR:-default}`, and `globinclude` rejects absolute paths.

So the include names `$HOME`, and the desktop writes kitty's file to exactly
that path rather than under `$XDG_CACHE_HOME` — the one output that does not
follow `XDG_CACHE_HOME`, because the program reading it cannot be told how. On a
machine that redirects that variable, kitty keeps `theme.conf` and logs a
missing include, which is the safe direction.

### Uninstalling

`uninstall.sh` **finds** what to unlink rather than keeping a list: it scans
`~`, `~/.config` (two deep), `~/.local/bin` and `~/.claude` for symlinks that
resolve into the repo, removes each, and moves back the `<name>.pre-dotfiles`
`link_config` made. A second copy of the installer's link list would drift.

`link_config` moves aside anything at the target that is not already this
repo's link — a real file, or someone's own symlink, which `ln -sfn` would
otherwise replace without a trace. The first thing moved aside at a path is
`<name>.pre-dotfiles`, and that name is never reused, so it is always the
original. Anything replacing the link after that (an app writing a real file
there) gets a `<name>.backup.<timestamp>` instead. Installs from before the
`.pre-dotfiles` name have only timestamped backups; for those the uninstaller
restores the most recent, since the oldest can be a stale leftover from an
earlier install/uninstall cycle. The one obligation it creates: **a new link outside
those locations must be added to `repo_links()`**, or uninstalling leaves it
dangling.

All of that lives in `lib/install.sh` — `info`, `run`, `link_config`,
`repo_links`, `remove_repo_links` and the pacman/AUR manifest installers —
sourced by both installers and the OS installers. **It is also an interface:**
the desktop repo sources `~/.dotfiles/lib/install.sh` instead of keeping a
copy, so renaming a function there breaks an installer this repo cannot see.
What counts as "this repo's" link is the `REPO_ROOTS` array each caller sets,
which is how one scan serves both repos.

`~/.claude/settings.json` is not restored from a backup, since what it held
before the merge cannot be told from the backups, which the merge also writes.
Only the registrations for this repo's hook scripts are removed, because they
name scripts that stop existing once `~/.claude/hooks` is unlinked.

Test it only against a scratch `HOME` (`env HOME=/tmp/fake ./uninstall.sh`);
run for real, it unlinks the machine it runs on.

### Adding a new OS or distro

1. Create `os/<name>/` with `install.sh` and `zsh/`
2. Have the installer install packages, set `NVM_SH`, and optionally define `os_link_configs()`
3. Extend `dotfiles_detect_os()` / `dotfiles_detect_distro()` in `lib/os.sh`

The OS installer is **sourced, not executed**, so it inherits `DOTFILES_DIR`, `DRY_RUN` and the `lib/install.sh` helpers — `info()`, `run()`, `link_config()`, `install_pacman_manifest()` — and hands `NVM_SH` back.

## Profile System Architecture

The profile system is the core architectural feature of this config. Understanding how it works requires reading multiple files:

### Profile Loading Flow

1. **`nvim/init.lua`** - Entry point that initializes the profile manager before loading plugins
2. **`nvim/lua/profile-manager.lua`** - Contains profile detection logic (checks `vim.g.nvim_profile`, env var `NVIM_PROFILE`, or persisted file)
3. **`nvim/lua/profiles/{profile}/plugins.lua`** - Profile-specific plugin configurations that get loaded by the profile manager
4. **`nvim/lua/configs/lspconfig.lua`** - General LSP configuration that applies across all profiles

### Key Profile System Details

- Profile selection order: command-line flag (`vim.g.nvim_profile`) → environment variable → persisted file (`~/.local/share/nvim/data/current_profile`) → "default"
- Profiles can be switched interactively via `:ProfileSwitch`, but requires a restart to take effect
- Each profile returns a Lua table of lazy.nvim plugin specifications
- The profile manager provides cross-platform utilities: `detect_os()`, `detect_arch()`, and `get_config_dir_name()`

### Cross-Platform Architecture Detection

The profile manager includes OS and architecture detection that's crucial for tools like jdtls:

- `M.detect_os()` returns `'mac'`, `'linux'`, or `'windows'`
- `M.detect_arch()` detects ARM vs x86_64 (important for Apple Silicon)
- `M.get_config_dir_name()` returns the correct jdtls config directory name (e.g., `config_mac_arm` for Apple Silicon)

**Critical for jdtls setup**: The Java profile uses these functions to dynamically select the correct jdtls configuration directory. On Apple Silicon, this must be `config_mac_arm`, not `config_mac`.

## Dashboard and session persistence

The split this setup is built around: **tmux owns projects, workspaces and processes; Neovim owns editing and navigation.** Anything that looks like project management inside nvim should hand off to tmux rather than grow a second implementation — which is what `nvim/lua/configs/projects.lua` is, and why there is no project-picker plugin.

### nvdash

The landing screen is NvChad's own `nvdash`, configured in `chadrc.lua`; there is no dashboard plugin. `header` is inherited from NvChad's defaults and only `buttons` is overridden — `buttons` is a list, so `tbl_deep_extend` replaces it wholesale rather than merging.

**Keep the footer line short.** nvdash centres every button on the width of the *widest* one, and the column it computes is `winw/2 - w/2 - 6`. A footer wider than the window drives that negative and `nvim_win_set_cursor` throws `Invalid cursor column: out of range` before the dashboard ever draws. Putting the cwd in the footer is enough to trigger it in a normal terminal; the cwd is on the statusline anyway.

A button's `cmd` is a string run as an Ex command (`vim.cmd`), not a function, so anything non-trivial goes through `lua require(...)`.

### persistence.nvim

Sessions save automatically on exit and are **never restored automatically**. That asymmetry is the whole design: an automatic restore fires when opening a single file from anywhere and drags in whatever was last open under that directory. Restoring is `s` on the dashboard, or `<leader>qs`.

Sessions are keyed by cwd **and git branch**, so the same checkout on two branches has two sessions, and a worktree has its own. Coming in through the sessionizer the cwd is the project root, which is what makes this project-scoped for free.

`<leader>q` was chosen because NvChad binds nothing under it; `<leader>p` is already profile switching plus NvChad's terminal picker.

**kulala.nvim declares `event = { "SessionLoadPost", "VimLeavePre" }` in its own upstream spec**, so every session restore loads it and runs its one-time tree-sitter grammar setup. A restore that suddenly prints git errors is kulala's grammar clone, not the session — check `~/.local/share/nvim/kulala.nvim/tree-sitter-kulala-http` has an `origin` remote. kulala ignores a failed `git remote add` and skips `init`/`remote add` whenever `.git` already exists, so a setup cut short between the two (plausibly nvim quitting, since `VimLeavePre` starts it too) fails with `'origin' does not appear to be a git repository` on every restore. Delete that directory; kulala re-clones it on the next load.

## LSP Configuration Gotchas

### jdtls Special Handling

jdtls (Java LSP) is **NOT** included in the `servers` list in `nvim/lua/configs/lspconfig.lua` because the `nvim-jdtls` plugin manages it separately with a custom configuration in the Java profile. Adding it to both places causes conflicts.

The Java profile configuration:
- Uses `vim.fn.glob()` to find the launcher jar (wildcards don't expand in Lua arrays)
- Must include both `on_attach` (for keymaps) and `capabilities` (for features like completion)
- Requires calling `require("nvchad.configs.lspconfig").on_attach()` to set up standard LSP keymaps like `gd`

### LSP on_attach Chain

All custom `on_attach` functions must call NvChad's default `on_attach` **first** to ensure standard LSP keymaps are set up:

```lua
local on_attach = function(client, bufnr)
  require("nvchad.configs.lspconfig").on_attach(client, bufnr)
  -- Then add custom keymaps or setup
end
```

### Inlay hints

Parameter names beside arguments, enabled globally in `mappings.lua` and toggled with `<leader>ih` (`<leader>th` is NvChad's theme picker). Enabling them client-side is only half of it: jdtls, ts_ls and omnisharp each send parameter-name hints only when asked in their settings. jdtls still omits a hint when the argument is a variable of the same name, a lambda, or a call into a class it has no source for, so a file of library calls can show very few.

**Only one client per buffer may send hints on Neovim 0.12.** It tracks a single version for all clients' hints, so after an edit one client's reply marks another's stale columns current, and drawing them fails with `Invalid 'col': out of range` (neovim#36318, fixed after 0.12). The Spring Boot language server attaches to Java buffers alongside jdtls, so the java profile gives it a no-op `textDocument/inlayHint` handler.

No SQL language server sends inlay hints, so `configs/sql-hints.lua` draws INSERT column names from the tree-sitter parse and follows the same global switch. It only works when the statement lists its columns — there is no database to ask.

## Test Runner System

The test runner (`nvim/lua/configs/test-runner.lua`) is a custom implementation that auto-detects test types and generates appropriate commands.

### Architecture

- **Pattern-based detection**: Each test type has a `pattern()` function that matches file paths
- **Command generators**: Functions like `run_file()`, `run_all()`, `debug_file()` dynamically build commands
- **Project-aware**: Detects Maven vs Gradle for Java, checks for Playwright config files
- **Cursor-aware**: `get_test_name_under_cursor()` extracts test names using regex patterns for different test frameworks

### Supported Test Types

- **Playwright, Jest, Vitest** (TypeScript/JavaScript): `*.{spec,test}.{ts,js}` files. One naming scheme serves all three, so `js_runner()` picks per file: a file importing `@playwright/test` is Playwright's (it has no globals, so its tests always import `test`); otherwise the nearest `package.json` decides — vitest, then jest, then Playwright. Before this every such file ran under `npx playwright test`, and a jest file failed with `describe is not defined`.
  - **A project whose tests go through its own scripts sets `js_test_cmd`** in its per-project file, e.g. `'yarn workspace {workspace} test {file}'`, and then every JS test file in it runs that instead of any guessed runner. `{workspace}` is the `name` of the nearest `project.json` or `package.json`, and `{file}` is the file relative to that directory, where `yarn workspace` runs a script. Run from the git root. Only file and whole-workspace runs: what a single test or a debugger needs depends on what the scripts forward.
  - Jest and vitest run from that package's directory and are given the file **relative to it**. Both filter by the path rather than open it — jest as a regex, vitest as a substring of the resolved path — so an absolute path misses through a symlinked checkout.
- **Java**: Detects `*Test.java`, `*Tests.java`, `*IT.java` files, generates Maven/Gradle commands
  - Maven file/single-test runs start from the reactor root (topmost `pom.xml` in the repo) with `-pl <module> -am`, so sibling modules compile from source rather than stale `~/.m2` jars. They pass `-DskipTests=false`, plus the project's `maven_test_args` (see **Per-project settings**) for a POM that filters tests out by a property (e.g. excluded JUnit tags).
- **.NET**: Detects `*Test.cs`, `*Tests.cs` files, uses `dotnet test --filter`
- **Python**: Detects `test_*.py`, `*_test.py` files, runs `python -m pytest` with the project's `.venv`/`venv` interpreter when one exists. Test-name lookup has its own Python pass, because the shared Playwright pattern also matches `s.split(",")`.

### Keymaps

- `<leader>rt` - Run current test file
- `<leader>rT` - Run all tests
- `<leader>rs` - Run single test under cursor
- `<leader>dt` - Debug current test file
- `<leader>dT` - Debug all tests
- `<leader>ds` - Debug single test under cursor

## Keybinding practice

`:KeyDrill` (`nvim/lua/configs/keydrill.lua`) opens on a choice of direction. One way shows a binding's description and waits for its keys; these are read with `getcharstr()` and compared, never executed, so a wrong guess runs nothing. The other shows the keys and you pick the description from four, the wrong three being other mapped bindings. `:KeyDrill!` widens the pool from `<leader>` maps to every normal-mode map; `:KeyDrill <leader>d` narrows it to one prefix.

- **The cards are the live keymap table**, global plus the starting buffer's local maps, so there is no list to keep in step with the config or the profile. **A map without a `desc` never appears.**
- One card per description; if several keys share one, any of them is right.
- Progress is a Leitner box per card in `stdpath("data")/keydrill.json`, per machine by design. The card id includes the keys, so rebinding something starts it over, and reverse cards are scored apart from forward ones.

## Per-project settings

`nvim/lua/configs/project-config.lua` reads `~/.config/dotfiles/nvim/projects/<name>.lua`, where `<name>` is the directory name of the project's git root, and the file returns a table. It mirrors `~/.config/dotfiles/tmux/{profiles,layouts}`: project specifics stay out of this public repo, one file per project.

- **Looked up from the path being worked on, not the cwd**, the same reason jdtls starts per buffer: one nvim can span several projects, and a setting must not leak from one into another. This is what a module-level variable set from `local-commands.lua` got wrong.
- **Read on every call, never cached.** Callers only use it when a command runs, so edits apply without a restart.
- A broken file warns instead of failing silently, unlike the `pcall` around `local-commands.lua`.
- Keyed by the git root's name, so a linked worktree (its own root, own name) does not pick up the main checkout's file.

Current keys: `maven_test_args` and `js_test_cmd` (test runner).

## Machine-local configuration

`~/.config/dotfiles/` (`$XDG_CONFIG_HOME/dotfiles`) holds everything machine-specific that this repo deliberately does not track: `zsh/{local.zsh,secrets,extensions}`, `nvim/{local.lua,projects}`, `tmux/{profiles,layouts,sessionizer-paths}`, `hypr/local.lua`.

**It is not `~/.config/<tool>/`, and that is the whole point.** `~/.config/nvim` and `~/.config/tmux` are symlinks *into this repo* — writing a machine-local file there writes it into a public checkout. That is the failure the nvim section below describes, and the reason a separate directory exists at all. The separation is load-bearing; only the name is a choice.

It was `~/.userconfig` until it moved here, for consistency with the XDG resolution the desktop tooling does. `install.sh` moves an existing `~/.userconfig` across on the next run, and refuses to choose if both exist.

Nothing here is tracked, so it exists in exactly one place per machine — which is why the desktop repo's `snapshot.sh` captures it.

## Machine-local Neovim code

`~/.config/dotfiles/nvim/local.lua` holds machine-specific nvim code — commands, keymaps, autocmds — the way `~/.config/dotfiles/zsh/local.zsh` does for the shell. `mappings.lua` runs it with `dofile` at the end of startup, and `:Reload local` runs it again, so whatever it defines must be safe to redefine (autocmds in an augroup with `clear = true`). A file that errors warns instead of being skipped silently.

It replaced a git-ignored `nvim/lua/local-commands.lua` inside the checkout, which could be committed by a `.gitignore` edit and was lost with the checkout. The ignore entry stays, as a guard for stale copies on machines that still have one. Settings consumed by tracked code belong in the per-project files above, not here; code scoped to one project checks the git root itself.

## DAP (Debug Adapter Protocol) Setup

### Multi-Language Support

The DAP configuration (`nvim/lua/configs/dap.lua`) supports:

- **.NET**: Uses `netcoredbg` from Mason, supports both launch and attach
- **Java**: Attach-only configuration on port 5005 (assumes remote debugging enabled)
- **TypeScript/JavaScript**: Uses `pwa-node` adapter for Node.js debugging

### Auto UI Behavior

DAP UI automatically opens on debug session start and closes on termination/exit via listeners. This can be disabled by removing the listeners at the bottom of `dap.lua`.

### Debugging Keymaps

- `<F5>` - Start/Continue
- `<F9>` - Toggle breakpoint
- `<F1>/<F2>/<F3>` - Step into/over/out
- `<F7>` - Toggle DAP UI
- `<leader>db` - Toggle breakpoint (alternative)

## Working with Profiles

### Testing Profile Changes

When modifying profile configurations:

1. Edit the profile's `plugins.lua` file
2. Run `:ProfileRestart` or restart nvim manually
3. Run `:Lazy sync` to install/update plugins
4. Check `:Lazy` to verify plugins loaded correctly

### Adding New Language Profiles

To add a new profile (e.g., Go):

1. Create `nvim/lua/profiles/go/plugins.lua` returning a lazy.nvim spec table
2. Add `"go"` to `M.profiles` array in `profile-manager.lua`
3. Follow the pattern from existing profiles for LSP setup (remember to call NvChad's `on_attach`)

A profile can branch shared config on `vim.g.current_nvim_profile`. `init.lua` sets it in `load_profile()`, before `configs.lazy` or `options` are required. The Python profile does this; see below.

### Common Profile Issues

- **LSP keymaps not working**: Check that `on_attach` calls `require("nvchad.configs.lspconfig").on_attach(client, bufnr)`
- **Plugins not loading**: Verify the profile returns a proper table structure, check `:Lazy` for errors
- **jdtls not starting**: Check launcher jar exists, config directory matches OS/arch, and jdtls is NOT in lspconfig servers list

## Python Profile and Jupyter

Interactive notebooks come from four plugins: **molten-nvim** runs code in a real Jupyter kernel and draws output inline (plots through the shared image.nvim spec); **jupytext.nvim** opens `.ipynb` as markdown and writes it back on save; **quarto-nvim** + **otter.nvim** give LSP/completion and cell-aware running inside the markdown code blocks. Keymaps are under `<leader>j` (`<leader>m` would prefix NvChad's `<leader>ma`).

### molten is a remote plugin, and this config disables remote plugins

Two separate switches have to be undone, and both are undone **only for the python profile**:

- **`nvchad.options` sets `g.loaded_python3_provider = 0`.** The provider's guard is `exists()`, so any value blocks it; `options.lua` *deletes* the variable after requiring `nvchad.options`. Setting it earlier would just be overwritten.
- **`configs/lazy.lua` lists `"rplugin"` in `disabled_plugins`.** lazy.nvim matches those names against runtime *filenames*, so `rplugin.vim` (which sources the `:UpdateRemotePlugins` manifest) is never loaded and no `:Molten*` command exists. The entry is filtered out of the list before `lazy.setup`.

molten is `lazy = false` on purpose: `:UpdateRemotePlugins` rewrites the whole manifest from the current runtimepath, so running it while molten isn't loaded silently deletes every `:Molten*` command. After molten is installed or updated, restart nvim once for the commands to appear.

### The Python host venv

`install.sh` builds `~/.local/opt/nvim-python` (next to the netcoredbg override) with pynvim, jupyter_client, ipykernel, jupytext, nbformat, pillow and pyperclip, and the profile sets `python3_host_prog` to it at module load. It is a venv because Arch's Python is PEP 668 externally-managed. It is *dedicated* because pointing the host at a project venv breaks molten in every project without pynvim.

- ipykernel's wheel ships a `python3` kernelspec into the venv, and jupyter_client finds it through `sys.prefix`, so `:MoltenInit` has a kernel on a fresh machine. Project kernels are registered with `ipykernel install --user` from the project's own venv.
- **molten writes connection files to `<jupyter data dir>/runtime` without creating it.** On a machine where Jupyter has never run, every `:MoltenInit` fails with ENOENT. The installer creates it, asking `jupyter_core` for the data dir (it is `~/Library/Jupyter` on macOS).
- **jupytext.nvim requires `jupytext` on PATH** and has no setting for it. Only that binary is linked into `~/.local/bin`. Putting the venv's `bin/` on PATH would shadow projects' `python`.
- The venv is rebuilt with `--clear` when `bin/python` is not executable, which is what a Homebrew Python minor-version bump leaves behind.

image.nvim's `magick_cli` processor needs ImageMagick's `magick`, which both manifests install.

### LSP

`pyright` and `ruff` are in the shared `servers` list. The loop wraps each server's `on_attach` so lspconfig's own hook still runs after ours; setting `on_attach` outright replaced it (`vim.lsp.config` merges with `force`) and dropped commands like `:LspPyrightSetPythonPath`. ruff's `hoverProvider` is switched off in its `on_attach`, otherwise `K` stacks ruff's lint-rule hover on top of pyright's. otter's LSP client (inside notebook cells) gets `gd`/`K` from NvChad's `LspAttach` autocmd like any other server. quarto-nvim no longer has a `keymap` option, despite molten's notebook guide passing one.

### Opening a notebook

A second `BufReadCmd *.ipynb` autocmd (defined after `jupytext.setup()`, so it runs after jupytext's read) schedules two things once the buffer is filled:
- It closes the fold on the YAML metadata header. That fold comes from `nvim/after/queries/markdown/folds.scm`, which extends nvim-treesitter's markdown folds with `minus_metadata`. Elsewhere, `foldlevel=99` leaves front matter open.
- It runs `MoltenInit <kernelspec.name>`, but only if that kernel is in `MoltenAvailableKernels()` and none is running in the buffer yet. So a notebook from another machine falls back to the picker, and `:e` never starts a second kernel.

### Formatting

conform loads on `BufWritePre` (`plugins/shared.lua`). Before that it had no trigger and only loaded on the first `<leader>fm`, so `format_on_save` silently did nothing until then, SQL included.

In the python profile, `.py` files format on save through `format_on_save`. Notebooks can't use that path. jupytext saves through a buffer-local `BufWriteCmd`, and Neovim sends no `BufWritePre` for a write a `BufWriteCmd` handles. So the jupytext spec re-registers that handler wrapped: format with conform's `injected` formatter, then run jupytext's own write. jupytext registers `BufWriteCmd` and `FileWriteCmd` under a single autocmd id, so deleting one deletes both, and `FileWriteCmd` is put back unwrapped. `formatters_by_ft.markdown` returns `injected` only for `.ipynb` buffers, so ordinary markdown code snippets are never rewritten.

### Validating headless

NvChad loads lspconfig on `User FilePost`, which only fires after `UIEnter`, so under `--headless` no LSP ever attaches unless the event is fired by hand. A test run can still rewrite the current profile's lockfile — the lockfile lives in the config dir, so pointing `XDG_DATA_HOME` elsewhere does not spare it — but only that profile's, so `git diff nvim/` after testing shows one file at most. See **Lockfiles are per profile** below.

## Node Profile

JavaScript/TypeScript. Most of it was already shared — `ts_ls` and the `pwa-node` DAP adapter serve every profile — so the profile mostly supplies the Mason tools those expect, plus neotest with the vitest and jest adapters. vitest is listed first: it only claims files in a project with vitest in its `package.json`, so jest gets the rest.

`eslint` is in the shared `servers` list, like pyright and ruff. It only attaches where an eslint config exists.

**Format on save is prettierd, and only where the project configures prettier.** `configs/conform.lua` sets `require_cwd` on prettierd, so a project with no `.prettierrc*`, `prettier.config.*` or `"prettier"` key in `package.json` is never restyled to prettier's defaults. Saving formats only in the node profile, the same split as python; in other profiles prettierd is still `<leader>fm`'s formatter for those filetypes, which falls back to the LSP where there is no prettier config.

## Lockfiles are per profile

`nvim/lazy-lock.<profile>.json` — one each for `default`, `dotnet`, `java`, `python` and `node`. All five are tracked. There is deliberately no `lazy-lock.json`.

**A single lockfile cannot work with this profile system.** `lazy/manage/lock.lua` loads the lockfile and then drops every entry not in the *current* spec:

```lua
for name in pairs(M.lock) do
  if not (Config.spec.disabled[name] or Config.spec.ignore_installed[name]) then
    M.lock[name] = nil
  end
end
```

A plugin belonging to another profile is in neither set, so it is purged. `install`, `update` and `clean` all trigger that write, and switching profiles auto-installs the new profile's missing plugins at startup — which is a write. So whichever profile ran last won, the other three silently lost their pins, and the file thrashed on every switch.

`configs/lazy.lua` sets lazy's `lockfile` option per profile, keyed on `vim.g.current_nvim_profile`. That variable is the *resolved* profile (already defaulted if an unknown one was requested), and `init.lua` sets it before requiring the module, so the filename can never name a profile that does not exist.

Consequences:

- **A shared plugin can sit at different commits in different profiles.** Updating under `dotnet` does not repin it for `java`. That is the intended trade: each profile's set stays internally consistent and reproducible.
- **Adding a profile means adding a lockfile.** It is created on that profile's first install; seed it by copying an existing one if you want the shared pins carried over.
- Rejected alternative: declaring every profile's plugins always with `enabled = false` for inactive ones, which would keep the entries. lazy merges specs by plugin name, so the four profiles' `nvim-treesitter` `ensure_installed` lists would merge into one — the exact breakage `plugins/shared.lua` is written to avoid.

## Git Ignore Patterns

Important git-ignored files:
- `nvim/lua/local-commands.lua` - No longer loaded (superseded by `~/.config/dotfiles/nvim/local.lua`); still ignored so a stale copy cannot be committed

## Mason Package Dependencies

Language servers and debuggers are installed via Mason:

- **Java**: `jdtls`, `java-debug-adapter`
- **.NET**: `omnisharp`, `netcoredbg`
- **TypeScript**: `typescript-language-server`, `js-debug-adapter`, `eslint-lsp`, `prettierd` (all four via the node profile's `ensure_installed`)
- **Python**: `pyright`, `ruff`, `debugpy` (all three via the profile's `ensure_installed`)

Install missing packages: `:Mason` then search and press `i` to install.

## Customization Patterns

### Adding Custom Keymaps

Add to `nvim/lua/mappings.lua` after line 5 (`local map = vim.keymap.set`). The file already loads at the end of initialization via `vim.schedule()`.

### Adding LSP Servers

For standard LSP servers (not jdtls):
1. Add server name to `servers` array in `nvim/lua/configs/lspconfig.lua`
2. Install via Mason if needed
3. The config applies NvChad defaults + custom `on_attach`

### Profile-Specific Keymaps

Add keymaps in the profile's plugin config function, not in global mappings.lua. This keeps profile-specific bindings isolated.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
