# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal dotfiles repository covering Neovim, zsh, and terminal configuration across macOS and Linux. The Neovim configuration is built on NvChad v2.5 and features a custom multi-profile system that loads different plugin sets and configurations based on the development environment (default, .NET, Java, or Python).

## Change workflow

**Two flows, chosen by what is being changed.** Desktop work can be tested
without being installed; everything else cannot, and that single fact is what
splits them.

### Desktop and rice work — `os/linux/desktop/**`

Stays on a branch until it is tested, then goes through a pull request.

1. **Fetch, then create the worktree.**
2. **Work in the worktree**, committing meaningful increments.
3. **Test in a nested compositor**, against the worktree's own config:
   ```sh
   os/linux/desktop/nested.sh --config .claude/worktrees/<name>/os/linux/desktop/init.lua
   ```
4. **Push the branch and open a PR. Stop there.** Merging is the user's.

**The PR is staging, not review.** There is still no second reviewer here, so
the global "a PR is a proposal" reasoning does not apply. It exists because a
rice is half-finished for long stretches, and `main` is *installed* — landing
an unfinished look means living in it, and blocks unrelated dotfiles work from
being tested at the same time.

**Nested testing is only honest if the config under test is self-contained.**
Anything reaching for `~/.dotfiles` resolves to the *main* checkout, so a
worktree silently tests `main` instead — which is how two bars ended up stacked
on top of each other. Paths must derive from the config's own location, the way
`init.lua` does with `debug.getinfo`.

**What nested cannot prove**, and still needs a real login:

- monitor layout and anything in `hypr/local.lua`
- the uwsm session entry and the display manager path
- NVIDIA environment and hardware cursors
- multi-monitor behaviour, including the workspace rules

A change resting on any of those is tested after the merge, not before.

### Everything else — nvim, zsh, tmux, the installer

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
install.sh             Shared install steps; dispatches to the OS installer
zsh/                   Shared shell configuration
kitty/ fastfetch/      Shared config sources (linked per-OS, see below)
tmux/                  Shared tmux config; OS fragment in os/<os>/tmux.conf
nvim/                  Shared; already cross-platform via profile-manager.lua
os/macos/              Brewfile, install.sh, zsh/{exports,aliases}.zsh
os/linux/              pacman.txt, aur.txt, install.sh, zsh/{exports,aliases}.zsh
os/linux/hypr/         User-tier Hyprland config (see below)
os/linux/hyde-themes/  Hand-authored HyDE themes, one dir each (see below)
os/linux/desktop/      Snapshot/restore and config verification (see below)
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

**On Linux this matters:** HyDE (the Hyprland desktop) generates and owns `~/.config/kitty` and `~/.config/fastfetch`, rewriting them on every theme switch — `kitty.conf` does `include hyde.conf`, and the Fastfetch logo comes from a theme-aware `fastfetch.sh logo` call. `os/linux/install.sh` detects HyDE (via `hyde-shell`/`hydectl`/`~/.config/kitty/hyde.conf`) and skips linking both, preserving the existing desktop setup. Without HyDE it links them normally. macOS always links them, since nothing else claims those directories there.

The Fastfetch startup banner still runs on Linux; it just renders with HyDE's config. `run_fastfetch` in `zsh/functions.zsh` points at `~/.config/fastfetch/config.jsonc`, whichever config that happens to be.

### tmux

`tmux/tmux.conf` is shared and linked to `~/.config/tmux/tmux.conf` by the shared installer. The only genuinely platform-specific part is clipboard integration, which lives in `os/<os>/tmux.conf`, is linked to `~/.config/tmux/os.conf`, and is pulled in by `source-file -q` at the end of the shared config. The `-q` keeps `tmux.conf` usable standalone.

This inverts the usual pattern: rather than the OS file loading first, tmux sources it **last**, because a `bind` simply replaces any earlier binding. So `y` in copy mode is bound to `wl-copy` on Linux and `pbcopy` on macOS, overriding nothing else.

The prefix is deliberately left at the default `C-b` — the config is written for someone learning tmux, where matching every tutorial and working unchanged over SSH matters more than ergonomics.

Two settings are load-bearing for Neovim and should not be removed: `escape-time 10` (the 500ms default makes `Esc` feel broken in nvim) and `focus-events on` (nvim's autoread). Colors are left to the terminal palette rather than hardcoded, so the status bar follows whatever HyDE theme is active.

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
- `bat` renders the README with `--theme=ansi`. Its default theme is hardcoded truecolor and would ignore the active tokyonight/HyDE palette.
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

#### Wallbash theming (Linux)

`os/linux/wallbash/tmux.dcol` is a wallbash template that regenerates `~/.config/tmux/wallbash.conf` from the current wallpaper on every theme, wallpaper or mode change, then re-sources it into any running server via its header-line command. `tmux.conf` sources it with `-q`, so macOS and non-HyDE machines fall back to the plain terminal-palette styling.

It is **copied**, not symlinked, into `~/.config/hyde/wallbash/always/` by `install_wallbash_templates()`. Wallbash finds templates with `find -H … -type f`, which does not follow symlinks — the same constraint as theme wallpapers. Re-run the installer after editing the template.

The template sets styles only; `tmux.conf` owns formats and layout. Keeping that split is what lets colors be regenerated without touching the bar's structure.

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

### Hyprland user configuration (Linux)

`os/linux/hypr/` holds the user-tier Hyprland files, linked into `~/.config/hypr/` by `install_hypr_configs()` — the list is the `HYPR_USER_CONFIGS` array: `userprefs.conf`, `keybindings.conf`, `windowrules.conf`.

These are safe to own because HyDE seeds but never rewrites them; its generated output goes to `~/.config/hypr/themes/` instead. Linking is HyDE-independent — it happens whether or not HyDE is installed.

**Deliberately excluded, and they must stay that way:** `monitors.conf` and `workspaces.conf` are both generated by nwg-displays and both name physical outputs (`monitor:DP-1`, `monitor:DP-2`), and `nvidia.conf` is hardware-specific. They describe *this* machine and would be wrong on any other. The nwg-displays pair is also regenerated whenever displays are rearranged, so tracking them means fighting that tool. Any file carrying a "Generated by … Do not edit manually" header belongs in this list, not in `HYPR_USER_CONFIGS`.

Remember the precedence rule when editing `userprefs.conf`: `hyprland.conf` sources it *last*, so it outranks the active theme. Keep structure and behaviour there and leave colors/gaps/rounding/blur to the theme, or theme switching will look half-applied.

**Hazard — HyDE updates can write through these symlinks.** HyDE's `restore.config.sh` deploys with `cp -r`/`cp -rf`, and a plain copy onto a symlink writes through to the target rather than replacing the link. A HyDE update can therefore overwrite the tracked files *inside this repo* while the symlinks still look correct. Installing HyDE before the dotfiles avoids it; otherwise check `git status os/linux/hypr` after any HyDE update and `git checkout --` to restore. This is the main reason these files are worth tracking in git at all.

### HyDE themes (Linux)

`os/linux/hyde-themes/` holds hand-authored HyDE themes, one directory each. `install_hyde_themes()` in `os/linux/install.sh` loops over them and installs each to `~/.config/hyde/themes/<name>`.

**The directory name is the theme name** — that's how HyDE identifies a theme, so no name is hardcoded anywhere. Adding a theme means adding a directory; renaming is a `git mv` plus deleting the stale `~/.config/hyde/themes/<old-name>` by hand, since the installer only adds.

Which files get symlinked is controlled by the `HYDE_THEME_LINKABLE` array; extend it if a theme needs a file type not yet listed. An optional `.sort` file (first line, a number, default `0`) orders the theme in the switcher — shipped themes use `1`–`12` and the sort is ascending, so custom themes appear first by default; a negative value pins one to the top.

Unlike Kitty/Fastfetch, this is **additive** — a directory HyDE doesn't own and never overwrites — so it installs whenever HyDE is present, regardless of the desktop-config skip. Without HyDE it isn't installed at all, since nothing would consume it.

**The symlink/copy split is forced by HyDE, not a style choice.** Discovery uses `find -H`, which does not follow symlinks encountered during traversal, so a symlink is `-type l` — never `-type d` or `-type f`:

| Path | Must be | Mechanism |
|------|---------|-----------|
| `themes/<name>/` | real directory | `get_themes()` uses `find -H … -maxdepth 1 -type d` |
| `wallpapers/` + images | real directory, **copied** files | `get_hashmap()` uses `find -H … -type f` |
| `*.theme`, `kvantum/` | may be symlinks | read by path (`-r`), which follows symlinks |

Get this wrong and there is no error — the theme simply never appears in the switcher. A theme with **no wallpaper at all is skipped entirely** by `get_themes()`, which is why one image is committed.

Consequences worth knowing:

- Editing a `.theme` file in the repo edits the live theme. Adding a wallpaper requires re-running the installer to copy it.
- HyDE writes `wall.set` and `wall.{swww,hyprlock,awww}.png` into the installed directory as wallpapers change. Because that directory is real rather than a symlink to the repo, this state never reaches the repo and **no `.gitignore` entries are needed**.
- `get_themes()` self-heals a missing or dangling `wall.set` by relinking it to the first wallpaper it finds.

### Desktop snapshots (Linux)

`os/linux/desktop/` holds the tooling for replacing HyDE with a Lua-native Hyprland config. The desktop is changed in place, so every phase of that work has to be reversible against a measured baseline rather than a hope that things rebuild themselves.

```sh
os/linux/desktop/snapshot.sh p0-baseline   # capture
os/linux/desktop/restore.sh --dry-run      # see what putting it back would change
os/linux/desktop/restore.sh                # put it back (asks first)
os/linux/desktop/verify-config.sh x.lua    # check a config before it reaches a login
```

Snapshots go to `$XDG_DATA_HOME/dotfiles/snapshots/<timestamp>[-label]`, **outside this repo** — the archive holds the shell history and other application state, and this repo is public. Data rather than state: XDG reserves state for things "not important or portable enough" to be data, and losing this one would matter. `DOTFILES_SNAPSHOT_DIR` overrides it. The first is ~2.6GB, mostly HyDE's 61 themes; later ones hardlink unchanged files against the previous snapshot via `--link-dest`, so one per phase costs almost nothing (measured: 2.4G then 232K).

**These scripts resolve the XDG base directories rather than assuming them**, and anything added here should keep doing so — including the Lua config, which belongs under `$XDG_CONFIG_HOME/hypr`. This machine has all four variables set to their defaults, so hardcoding `~/.config` would work by coincidence, and coincidence is exactly how `dev` broke: it assumed `~/.zshrc` while `ZDOTDIR` pointed at `~/.config/zsh`. `~/.local/lib` and the legacy `~/.gtkrc-2.0`/`~/.zshenv`/`~/.zshrc` stay `$HOME`-relative because no XDG variable covers them.

Because the archive stores `$HOME`-relative paths, a base directory pointing **outside** `$HOME` is refused rather than silently skipped — a snapshot that looks complete and restores a partial desktop is the worse outcome. Restore never reinterprets the paths inside an archive: it replays `PATHS` as recorded, so an archive taken under one layout restores to that layout instead of being relocated into the current one.

**`~/.config/dotfiles` is the most irreplaceable thing captured.** It is where this repo keeps what it deliberately does not track — tmux profiles and layouts, nvim per-project settings, zsh secrets and extensions, and `hypr/local.lua` with this machine's monitor geometry and graphics settings. Everything else in the archive can be reinstalled or recloned; that directory exists in one place only. It contains secrets, which is not a reason to omit it: the archive already holds the shell history and lives outside this public repo.

**Configuration alone does not describe a desktop.** `~/.local/state/hyde/staterc` names the *active* theme, `~/.local/share/{waybar,rofi}` hold the layouts it points at, and `~/.local/share/themes` is the target of the captured `~/.config/gtk-4.0` symlink — without it that link restores dangling. `~/.local/state/hyde` is captured minus `python_env`/`pip_env`, which are 638MB of the 639MB and are package-manager build output. `~/.local/share/icons` (6.7GB) is left out as an installed asset nothing here modifies.

**The archive describes itself.** `PATHS` records the captured roots, `MANIFEST` the file checksums, `SYMLINKS` the link targets, `META` the provenance — including `~/HyDE`'s remote and commit, since recording where a clone came from beats copying it. `restore.sh` reads all of that rather than keeping a second copy of the path list, for the same reason `uninstall.sh` finds links instead of listing them: a second copy drifts, and drift here means a restore that quietly misses something.

**MANIFEST is written last, and that is what marks a snapshot complete.** Both scripts pick "the latest" by looking for it, so an interrupted snapshot is never hardlinked against and never shadows the good one next to it.

Details that are load-bearing rather than incidental:

- **Symlinks are captured as symlinks, and verified apart from the manifest.** Hashing one would hash its target, which says nothing about the link. `~/.config/gtk-4.0` points into `~/.local/share/themes/`, and a wrong target there restores cleanly and breaks the desktop. Both sides of that comparison are re-sorted under `LC_ALL=C`: bare `sort` follows the locale, so an archive written under a UTF-8 login and checked from a rescue shell would be declared corrupt — exactly when the tool is needed.
- **Restore deletes files a snapshot does not contain**, scoped to one captured root at a time. An addition is only undone if it goes away — and `hyprland.lua` outranks `hyprland.conf`, so a file left behind by an abandoned phase would keep control of the session.
- **A destination whose type does not match is cleared first**, both ways round. A symlinked destination directory is the HyDE write-through hazard again: `rsync --delete` resolves the link and empties whatever it points at, outside the target entirely. A directory where a symlink belongs is the mirror image — rsync cannot make way for it, fails with status 23, and would take the rest of the restore with it.
- **PATHS is treated as input, not trusted.** It is plain text inside the archive and is not covered by MANIFEST, so a root that is `.`, absolute, or contains `..` is refused. Scoping deletes to a root only means something if the root cannot climb out of it.
- **A failing root is collected, not fatal.** Aborting on the first would leave the desktop half restored with no report of where it stopped, and `.config/gtk-4.0` sits twelve of thirty-one in.
- **Packages are recorded, never reinstalled.** Reinstating a package set is a decision about the system, not about configuration.

#### The session entry, and the `--` in it

`os/linux/desktop/session/hyprland-dotfiles.desktop.in` installs a second login session running the Lua config, alongside whatever is already there. The config is passed with `--config` rather than by exporting `HYPRLAND_CONFIG`, which HyDE assigns unconditionally from its own uwsm env fragment — `--config` outranks the variable and needs no HyDE file edited. Removing the entry reverts to HyDE entirely.

The compositor is launched through **`start-hyprland`**, not the `Hyprland` binary. That wrapper supervises the compositor with a watchdog, and running the binary directly prints *"Hyprland is being launched without start-hyprland. This is highly advised against."* at every login. Naming it first does mean uwsm takes it as the compositor id, so the generated units are `wayland-wm@start-hyprland.service` rather than `@Hyprland` — cosmetic here, since nothing references those names and `-D Hyprland` still sets `XDG_CURRENT_DESKTOP`, which is what the env files key off.

**There are two `--` in that Exec and they do different jobs.** The second tells `start-hyprland` which arguments to pass on to Hyprland. The first is load-bearing for a different reason: uwsm parses its command line with argparse, takes the compositor as a plain positional, and never calls `parse_known_args`, so a trailing option is read as one of *uwsm's* and rejected:

```
uwsm: error: unrecognized arguments: --config /home/…/init.lua
```

uwsm then exits before Hyprland is ever reached, and the display manager returns to the greeter — which presents as a failed login, not a malformed command. HyDE's own entry needs no `--` only because a Desktop Entry ID takes no trailing options.

So the installer checks the Exec line as well as the config, with `uwsm start -n` (writes and starts nothing, safe from inside a running session). **It reads the line from the template and substitutes it exactly as the entry will be**, rather than rebuilding an equivalent command — a check that passes while the installed entry is broken is worse than no check. Verifying the config proves the compositor would accept it and says nothing about the command line that launches it.

#### Colours go through the palette, never into a config file

`os/linux/desktop/lib/palette.lua` is the one place a colour is written down. Every module does `require("lib.palette")` and reads a name; **no config file contains a hex literal.** It exposes `rgb()`/`rgba()` because Hyprland takes `rgb(RRGGBB)` rather than CSS hex, while consumers that do take hex read the values directly.

This is sequencing, not neatness. The theme engine is deliberately deferred until the consumers it must reload exist (see the theme-engine issue), and that deferral only costs nothing if colours are already funnelled through one file. When it lands, `palette.lua` loads generated data and falls back to today's literals — **one file body changes and no consumer is touched.** Written the other way round, every module from P2 through P5 would need hunting down.

The fallback values are a floor, not a theme: a missing or half-written cache must give a dull desktop, never an unstartable session, because a config that errors takes the login with it.

The same discipline applies per consumer as each arrives — waybar gets an `@define-color` block, rofi a `*` block, kitty a single included file. That is already how `os/linux/hyde-themes/Custom/{waybar,rofi,kitty}.theme` are written, so the pattern is borrowed rather than invented.

Note that `--verify-config` does check colour *values*, not just syntax: a malformed one fails with `invalid color "…"`, so a palette mistake is caught before a login rather than at one.

#### Verifying a config runs it

`Hyprland --verify-config` parses without starting a session, which is what makes it usable as an install step and a pre-commit check. But a Lua config *is* a Lua program, and verifying it runs that program. Measured on 0.56.2:

| | during `--verify-config` |
|---|---|
| `hl.exec_cmd(...)` top level | runs — launches the application |
| `os.execute(...)` / `io.popen(...)` | runs |
| `hl.dispatch(hl.dsp.exec_cmd(...))` | runs |
| an exec indented inside a top-level `for` | runs |
| an exec in a function called at the top level | runs |
| `hl.dsp.exec_cmd(...)` passed to `hl.bind` | **does not** — it builds a dispatcher |
| anything inside `hl.on("hyprland.start", ...)` | does not run |

So **every exec belongs inside `hl.on("hyprland.start", ...)`**, which is also how Hyprland's own example config is written. Otherwise verifying launches the autostart set — on every commit, for a hook.

The last two rows are why `verify-config.sh` checks this **per file rather than per line**: indentation says nothing (an exec inside a top-level loop still runs), and an exec reached through a function call cannot be spotted by grep at all. So it asks whether a file that execs has an `hl.on("hyprland.start")` to put them in. It scans the entry point **and every `.lua` beside it** — every exec in this desktop lives in `config/startup.lua`, which a check reading only the file it was given would never open. Bindings are not flagged because `hl.dsp.exec_cmd` does not contain the substring `hl.exec_cmd`. Still a warning rather than a failure: a file may legitimately hold a helper only ever called from inside the callback.

It checks both the exit status and the `config ok` line. The status is correct on 0.56.2; agreeing with both costs nothing against a release where either changes.

#### The bar is vendored, not cloned

`os/linux/desktop/quickshell/pill/` is a verbatim copy of [Ricelin](https://github.com/Gakuseei/Ricelin)'s
Quickshell pill at commit `2109754024` (2026-09-26), MIT, with its `LICENSE`
beside it and provenance in `VENDORED.md`.

**Copied on purpose, rather than pinned as a submodule or a clone.** A pin makes
local edits vanish the next time it moves, and the reason for taking this code
is to change it. The cost is that upstream fixes have to be pulled across by
hand; the cost of the alternative is losing work to a version bump, which is
worse. Diffing against upstream means re-cloning at the recorded commit.

It is one bar and also most of the desktop: media with now-playing, calendar,
wallpaper picker, clipboard history, mixer, network, bluetooth, tray,
**notifications**, launcher and power menu. That is why `config/startup.lua`
starts so little else — waybar, a wallpaper setter and the wifi/bluetooth
applets are all things the pill already is.

**dunst needs no masking.** The pill claims `org.freedesktop.Notifications` at
startup, only one process may own that name, so dunst is never D-Bus activated
while the pill holds it. If the pill dies the next notification starts dunst,
which is a fallback worth keeping rather than a conflict to suppress.

#### Binding a surface needs the monitor named

The launcher and clipboard are surfaces of the bar, reached over Quickshell IPC:

```sh
qs -p <pill path> ipc call pill launcher "$(hyprctl activeworkspace -j | jq -r .monitor)"
```

Addressed by **path**, because `qs -c pill` only resolves a config installed
under `~/.config/quickshell` and this one is read out of the repo.

**The monitor is looked up rather than passed empty, and that is not caution.**
`toggleSurface` falls back to Quickshell's `Hyprland.focusedMonitor` for an empty
string, and that property is populated from the `focusedmon` event — so it is
null until focus has *changed* at least once. Hyprland itself reports the monitor
as `focused=true` the whole time, so nothing looks wrong; the surface simply
never opens. It fails exactly when the desktop is freshest: right after login,
before focus has moved. Measured in a nested session — with `""` nothing renders,
with the name it opens immediately.

Asking for a surface that is already open closes it, so toggling is free and the
`pkill -x rofi ||` prefix the rofi bindings carried is not needed.

Upstream binds none of this; they open surfaces by clicking the pill, which is
why there is no reference invocation to copy.

#### Theming the pill is writing one file

The pill reads every colour from `$XDG_CACHE_HOME/ricelin/colors.json` and
watches it with `FileView`, so **a theme change is a write to that file and
nothing restarts.** `render-theme.lua` generates it from `lib/palette.lua` along
with every other config that carries a colour — see **Generated configs** below.
At P6 matugen produces the palette and nothing downstream changes.

The mapping is 17 Material You token names onto this repo's ramp: surfaces
ascend `base → raised → overlay → muted`, the accent pair carries focus, and the
text family stays neutral so it holds contrast on any of those surfaces.

**Two files, and one without the other does nothing.** `paletteMode` in
`$XDG_STATE_HOME/ricelin/flags.json` must not be `"static"`, or `Theme.qml`
ignores `colors.json` entirely and renders Ricelin's curated vermilion identity.
That file also holds the weather city, wallpaper directory and recording
settings, all editable from the pill's own UI — so it is **merged with `jq`,
never overwritten**, or applying a theme would reset all of it.

A missing `colors.json` is not fatal: `Dyn.qml`'s `JsonAdapter` carries upstream's
warm amber defaults, so the failure mode is the wrong colours rather than an
unusable bar. The installer still writes it on every run, which is also how a
`palette.lua` edit reaches the bar.

**Test it without touching the live session:**

```sh
os/linux/desktop/nested.sh --exec "quickshell -p $PWD/os/linux/desktop/quickshell/pill"
```

Two upstream warnings are expected and neither is a fault: a `Binding` in
`shell.qml` targets a `dnd` property `Notifs.qml` does not declare (do-not-disturb
works anyway — `Notifs` reads `Flags.dnd` directly at the point of use), and the
notification server fails to register inside a nested session because the real
one outside already owns the name.

#### A rice is a directory, and one state file picks it

`os/linux/desktop/rices/<name>/` holds `palette.lua` (the colours) and
`rice.lua` (which provider fills each role, plus the non-colour knobs). That is
everything a look is, apart from the machine it runs on.

```sh
os/linux/desktop/rice.sh                 # list, marking the active one
os/linux/desktop/rice.sh switch slate    # wear a different one
```

Which one is active lives in `$XDG_STATE_HOME/dotfiles/rice`, **not in the
repo** — so a machine can wear a different look without a commit, and the
choice does not follow a push to another machine.

**Both halves are partial.** A rice that only changes the launcher names only
the launcher; roles and colours it leaves out keep what they had. Roles inherit
through a metatable, which is why `start_commands()` walks the *defaults* table
— `pairs()` does not see inherited keys, so iterating the active table would
shrink the desktop to whatever roles the rice happened to mention.

**Nothing in the resolution is fatal.** A missing state file, a stale name, a
`rice.lua` that does not parse — each falls back and warns, because this is
runtime state a switch can leave half-written. That is deliberately the opposite
of `lib/roles.lua`, which raises: the roles table is repo code with
`verify-config.sh` in front of it. Warnings surface as notifications from
`init.lua`, since `lib/rice.lua` is loaded while the config is still parsing and
has no session to notify yet.

**The palette's fallback is flat grey on purpose**, and is not a copy of any
real scheme. A rice that fails to load should give a desktop that plainly looks
wrong rather than a plausible one that quietly is — and a drab floor can never
drift from a scheme the way a duplicate would. `lib/look.lua`'s defaults are the
opposite: a working desktop, because a missing gap size has no visual tell.

**A switch applies in place, except for providers.** Colours, gaps, rounding,
blur and motion all change on `hyprctl reload`. Changing which *program* fills a
role does not, because reload re-reads the config without re-running autostart —
so `rice.sh` compares the start commands either side of the switch and says a
re-login is needed. It asks the roles table rather than the rice, which is what
keeps that right as providers change.

**A switch is machine-wide even from a worktree.** The state file and the
rendered output live under XDG paths, one set per machine rather than per
checkout, and the bar watches its colour file — so running `rice.sh` from a
branch repaints the desktop you are sitting in. There is no isolated way to try
it: the bar's colour path is fixed by the vendored code and cannot be
redirected.

#### Generated configs

**No config outside `lib/palette.lua` contains a colour.** `render-theme.lua`
substitutes them into templates, because hyprlock parses hyprlang, wlogout
parses CSS and the bar reads JSON — none can require Lua. Before it existed each
carried the palette typed out a second time, which works while there is one
palette and silently keeps the old colours the moment there are two.

**What it renders is not a fixed list.** It asks `lib/roles.lua` for the
*active* providers and renders the templates they declare, so swapping a
component stops its template being rendered with no edit to the renderer.

| Template | Output |
|---|---|
| `hyprlock.conf.in` | `$THEME_DIR/hyprlock.conf` |
| `wlogout/style.css.in` | `$THEME_DIR/wlogout.css` |
| `quickshell/pill-colors.json.in` | `$XDG_CACHE_HOME/ricelin/colors.json` |

`$THEME_DIR` is `$XDG_CACHE_HOME/dotfiles/theme/`. The pill's path is fixed by
the vendored code, which is why that one output sits elsewhere; its template
still lives *beside* the vendored tree rather than in it, so that copy stays
verbatim.

Two substitution forms: `@name@` is CSS hex, `@name:bare@` drops the leading `#`
for hyprlang's `rgba()`. **Substitution is textual and covers the whole file,
comments included** — a template cannot spell a token out to document itself.
An unknown name is fatal rather than left in place, because a stray `@accnet@`
would otherwise reach hyprlock as a literal and fail at a lock screen.

Rendered at install and again at session start — first in the startup sequence,
since hypridle locks on a timer and the lock screen is one of the generated
files. So **a `palette.lua` edit reaches every consumer at the next login**
without running the installer.

Output is a cache: generated, disposable, untracked, and a hand-edit there is
overwritten by the next render. That is the contract keeping the palette the
single source. A missing file costs one render, and for the lock it fails safe —
hyprlock refuses to start without a config, so the failure is *no lock* rather
than a lock screen that cannot be dismissed.

**`paletteMode` is separate and is setup, not theming.** `Theme.qml` ignores
`colors.json` entirely while it is `"static"`, its default, so
`quickshell/pill-flags.sh` sets it once at install. It is merged with `jq`
because that file also holds the weather city, wallpaper directory and
recording settings, all editable from the pill's own UI.

**Still hand-themed, and only because HyDE does it today:** tmux reads
`~/.config/tmux/wallbash.conf` and kitty an `include theme.conf`, both
regenerated by HyDE. `source-file -q` means tmux loses its colours *silently*
when HyDE goes. Both belong in the table above before P8.

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

Copied files are not links and are handled by name: HyDE theme directories are
removed, and a wallbash template only when it still matches the repo's copy.
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

The OS installer is **sourced, not executed**, so it inherits `DOTFILES_DIR`, `DRY_RUN`, `info()`, `run()`, and `link_config()` — and hands `NVM_SH` back.

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

- **Playwright/Jest** (TypeScript/JavaScript): Detects `*.spec.ts`, `*.test.ts` files
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

Current keys: `maven_test_args` (test runner).

## Machine-local configuration

`~/.config/dotfiles/` (`$XDG_CONFIG_HOME/dotfiles`) holds everything machine-specific that this repo deliberately does not track: `zsh/{local.zsh,secrets,extensions}`, `nvim/{local.lua,projects}`, `tmux/{profiles,layouts,sessionizer-paths}`, `hypr/local.lua`.

**It is not `~/.config/<tool>/`, and that is the whole point.** `~/.config/nvim` and `~/.config/tmux` are symlinks *into this repo* — writing a machine-local file there writes it into a public checkout. That is the failure the nvim section below describes, and the reason a separate directory exists at all. The separation is load-bearing; only the name is a choice.

It was `~/.userconfig` until it moved here, for consistency with the XDG resolution the desktop tooling does. `install.sh` moves an existing `~/.userconfig` across on the next run, and refuses to choose if both exist.

Nothing here is tracked, so it exists in exactly one place per machine — which is why `os/linux/desktop/snapshot.sh` captures it.

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

## Lockfiles are per profile

`nvim/lazy-lock.<profile>.json` — one each for `default`, `dotnet`, `java` and `python`. All four are tracked. There is deliberately no `lazy-lock.json`.

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
- **TypeScript**: `typescript-language-server`, `js-debug-adapter`
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
