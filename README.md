# dotfiles

Personal Neovim, zsh, tmux, and terminal configuration for **macOS (Apple
Silicon)** and **Arch-based Linux**, from one repository.

The two platforms share the editor, shell and tmux setup. Everything
Linux-desktop related (Hyprland, HyDE, window-manager config) is Linux-only and
never runs on a Mac. **This repo never installs HyDE on either platform.**

## Install

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # prints every step; changes nothing
./install.sh
```

Add `--no-claude` to skip the Claude Code configuration (see below). Flags
combine: `./install.sh --dry-run --no-claude`.

The installer detects the platform and runs the matching setup from `os/`. Run
the dry run first. It is an opinionated personal setup, and it replaces some
existing configuration (see below).

## What the installer does on macOS

**Packages**, via Homebrew (installed first if missing), from
`os/macos/Brewfile`:

- CLI tools: git, neovim, tree-sitter-cli, fzf, zoxide, fastfetch, bat,
  ripgrep, jq, lazygit, tmux, nvm, pnpm, tree, python, imagemagick
- Apps: the Kitty terminal and the CaskaydiaCove Nerd Font

`brew bundle` also **upgrades** any of these that are already installed but
outdated.

**Also installed:**

- Node LTS through nvm, set as the default, if no LTS version is installed yet
- Oh My Zsh and two plugins (your login shell is not changed)
- netcoredbg (the .NET debugger) in `~/.local/opt`
- A Python virtualenv for Neovim's notebook support, in `~/.local/opt/nvim-python`
- tmux's plugin manager (tpm)

**Linked** into your home directory, as symlinks pointing back at this repo:

| Path | What |
|------|------|
| `~/.zshrc` | zsh configuration |
| `~/.config/nvim` | Neovim (NvChad-based, with language profiles) |
| `~/.config/tmux/` | tmux configuration |
| `~/.config/kitty/`, `~/.config/fastfetch/` | terminal and startup banner |
| `~/.local/bin/tmux-sessionizer` | project/session picker |
| `~/.claude/CLAUDE.md`, `agents/`, `skills/`, `hooks/` | Claude Code instructions and tooling |

An existing file or directory at any of these paths is **moved aside** to
`<name>.backup.<timestamp>` first, never deleted. `~/.claude/settings.json` is
merged rather than replaced, keeping your own settings in it.

**If you use Claude Code,** note that the linked `~/.claude` files replace your
global instructions, agents, skills and hooks with the ones in `claude/`. Run
the installer with `--no-claude` to leave `~/.claude` untouched; nothing else
depends on it.

Nothing Linux-specific runs on macOS: no pacman or AUR packages, no Hyprland,
no HyDE themes.

## What the installer does on Linux

The same shared steps as macOS (Oh My Zsh, nvm, Neovim, tmux, Claude Code
unless `--no-claude`, `~/.userconfig`), plus:

- Packages from `os/linux/pacman.txt` (`pacman -S --needed`) and
  `os/linux/aur.txt` (via `paru` or `yay`). This includes a **Hyprland desktop**
  package set (Hyprland, SDDM, Wayland utilities), so it assumes you want a
  Hyprland machine.
- The user-level Hyprland config in `os/linux/hypr/`, linked into
  `~/.config/hypr/`.
- If HyDE is **already** installed: the custom HyDE themes and a tmux color
  template. Kitty and Fastfetch are then left to HyDE rather than linked.

HyDE is a separate project you install yourself; see
[Linux: Hyprland and HyDE](#linux-hyprland-and-hyde).

## Layout

Shared configuration lives at the top level. Anything that genuinely differs
per platform lives under `os/<os>/`.

```
lib/os.sh             OS detection, shared by the installer and zsh
install.sh            Shared install steps; dispatches to the OS installer
zsh/                  Shared shell configuration
kitty/ fastfetch/     Config sources (linked per-OS)
tmux/                 Shared tmux config (clipboard bits in os/<os>/tmux.conf)
claude/               Claude Code harness (CLAUDE.md, agents, skills, hooks)
nvim/                 NvChad-based config with a multi-profile system
os/macos/             Brewfile, install steps, macOS-only zsh
os/linux/             pacman.txt, aur.txt, install steps, Linux-only zsh
os/linux/hypr/        Linux only: user-tier Hyprland config
os/linux/hyde-themes/ Linux only: custom HyDE themes, used when HyDE is present
```

`os/<os>/zsh/` is sourced *before* the shared `zsh/` files. The OS files own
what differs — package-manager paths, `NVM_SH`, `JAVA_HOME`, the `ls` color
flag — and the shared files build on those.

## Packages

Two parallel manifests, kept in sync by hand:

- macOS — `os/macos/Brewfile` (`brew bundle`)
- Linux — `os/linux/pacman.txt` (`pacman -S --needed`), plus
  `os/linux/aur.txt` for anything not in the official repos

Adding a cross-platform tool means adding it to both. The Hyprland desktop
section of `pacman.txt` is Linux-only by nature and has no Brewfile counterpart.

## tmux

`tmux/tmux.conf` is shared and linked to `~/.config/tmux/tmux.conf`. Clipboard
integration is the one platform-specific part — `wl-copy` on Linux, `pbcopy` on
macOS — and lives in `os/<os>/tmux.conf`, linked to `~/.config/tmux/os.conf` and
sourced at the end of the shared config.

The prefix stays at the default `C-b`, so every tutorial applies and it behaves
the same on machines you SSH into. Press `C-b r` to reload after editing, and
`C-b ?` to list every binding.

| Key | |
|-----|-|
| `C-b \|` / `C-b -` | split left-right / top-bottom, in the current directory |
| `C-b h j k l` | move between panes |
| `C-b H J K L` | resize (repeatable — hold prefix once) |
| `C-b z` | zoom a pane (toggle) |
| `C-b [` | copy mode; `v` select, `y` yank to system clipboard |

### Sessions

One session per project. `C-b f` fuzzy-finds a project under `~/Repos` (and
`~/dotfiles`) and switches to a session named after it, creating it if needed.
The same script is on `PATH` as `tmux-sessionizer`, so it works from a plain
shell. Edit `SEARCH_PATHS` in `tmux/scripts/tmux-sessionizer` to add roots.

| Key | |
|-----|-|
| `C-b f` | fuzzy-find a project → session |
| `C-b S` | session tree |
| `C-b Space` | previous session |
| `C-b C-s` / `C-b C-r` | save / restore sessions by hand |

Sessions are saved automatically every 15 minutes by tmux-continuum and
restored when the tmux server starts, so a reboot doesn't cost you your
workspace. To start clean instead, set `@continuum-restore` to `off`.

Plugins are managed by tpm, which `install.sh` clones. Press `C-b I` inside
tmux to install them, `C-b U` to update.

### Theming

On macOS, and on Linux without HyDE, tmux uses the terminal's own palette.
On Linux with HyDE, the status bar colors are generated from your current
wallpaper — `os/linux/wallbash/tmux.dcol` regenerates
`~/.config/tmux/wallbash.conf` on every theme or wallpaper change, and tmux
picks it up immediately.

## Claude Code

`claude/` holds a small, reusable Claude Code harness — global instructions,
three subagents, four skills, and two hooks that block destructive git commands
and surface the working tree at the end of a turn.

This repo is public, so `~/.claude` is **never** linked as a whole: it holds
session transcripts, credentials, plugin state, and the per-project memory
Claude writes under `projects/`. Only the four generic paths below are linked,
and `settings.json` is *merged* rather than symlinked, because Claude Code
writes to that file itself and the auto-mode block it maintains records
organisation and infrastructure details.

```
~/.claude/CLAUDE.md  agents/  skills/  hooks/   symlinked to this repo
~/.claude/settings.json                         merged at install time
everything else, and ~/.claude.json             stays private, never tracked
```

The rule this enforces: **the harness may describe how I work, never what I am
working on.** No project names, hostnames, domains, org names, or paths.

Changing a permission or hook means editing `claude/settings.json` and re-running
`./install.sh`; everything else is live on save. See `claude/README.md`.

## Machine-specific configuration

`~/.userconfig` is never tracked here. It holds everything local to a machine
or a project, so it is the one directory to back up:

```
~/.userconfig/zsh/local.zsh            Machine-specific shell settings
~/.userconfig/zsh/extensions/          Work/project shell extensions
~/.userconfig/zsh/secrets/             Private environment variables
~/.userconfig/tmux/sessionizer-paths   Extra project roots for the sessionizer
~/.userconfig/tmux/profiles/<session>  nvim profile a project's session opens with
~/.userconfig/tmux/layouts/<session>   Per-project window layout script
~/.userconfig/nvim/local.lua           Machine-specific Neovim code
~/.userconfig/nvim/projects/<repo>.lua Per-project Neovim settings
```

It contains secrets, so keep backups encrypted and never publish it.

## Linux: Hyprland and HyDE

Everything in this section applies to Linux only. None of it runs on macOS.

### Installing HyDE

On a Linux machine that will use HyDE, it is a **prerequisite**, not something
this installer sets up — install it first, then run `./install.sh`. Doing it in the other order links this repo's
Kitty and Fastfetch configs into paths HyDE also wants; re-running the installer
afterwards corrects it.

```sh
git clone https://github.com/HyDE-Project/HyDE ~/HyDE
# run HyDE's own installer, then:
./install.sh
```

The repo tracks the user-tier Hyprland files (`os/linux/hypr/`) and any custom
themes, and leaves everything HyDE generates alone.

`monitors.conf`, `workspaces.conf` and `nvidia.conf` are intentionally **not**
tracked. The first two are generated by nwg-displays and name physical outputs
(`monitor:DP-1`), so they describe one machine and would be wrong on another —
and that tool rewrites them whenever displays are rearranged.

### After updating HyDE

HyDE's `restore.config.sh` deploys configs with `cp -rf`, and a plain copy onto
a symlink **writes through it** — overwriting the file in this repo while
leaving the symlink looking fine. Installing HyDE *first* avoids this entirely,
but a later HyDE update can hit it.

So after updating HyDE, check the repo:

```sh
git -C ~/dotfiles status --short os/linux/hypr
git -C ~/dotfiles checkout -- os/linux/hypr   # if it clobbered them
```

Being tracked in git is what makes this recoverable rather than a silent loss.

### Kitty, Fastfetch and themes

If HyDE (the Hyprland desktop) is detected, both directories are left
untouched — HyDE generates them and rewrites them on every theme switch. The
Fastfetch startup banner still runs; it just uses HyDE's config. On a Linux
machine without HyDE, the repo's versions are linked as on macOS.

When HyDE *is* present, every directory under `os/linux/hyde-themes/` is
installed as a custom theme — additive, so they sit alongside the shipped themes
without overwriting anything. The directory name is the theme name:

```sh
hydectl theme set "Custom"
```

See `os/linux/hyde-themes/README.md` for how to add another, and why theme text
files are symlinked but wallpapers are copied — HyDE's `find -H` discovery makes
that mandatory, not a preference.
