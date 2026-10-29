# dotfiles

Personal Neovim, zsh, tmux, and terminal configuration for **macOS (Apple
Silicon)** and **Arch-based Linux**, from one repository.

The two platforms share the editor, shell and tmux setup. The Linux Hyprland
desktop is a separate repository,
[kseeman/desktop](https://github.com/kseeman/desktop), installed on top of this
one, so a machine that does not want it never carries it.

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

## Uninstall

```sh
cd ~/dotfiles
./uninstall.sh --dry-run   # prints every step; changes nothing
./uninstall.sh
```

It removes every symlink that points into this repo and puts back the
`<name>.pre-dotfiles` the installer made of what it replaced, so the files from
before the install return. It also removes this repo's hooks from
`~/.claude/settings.json`. On the Linux desktop, run the desktop repo's
`uninstall.sh` first: it reads its helpers from this repo.

Left in place, and listed at the end: Homebrew or pacman packages, Oh My Zsh
(`uninstall_oh_my_zsh` removes it), Node versions, `~/.config/dotfiles`, and the
checkout itself. `--remove-tools` also deletes the Neovim Python environment,
netcoredbg, and tmux plugins the installer downloaded.

Edits made to a linked file since installing were made to the repo's copy, so
copy out anything you want to keep before uninstalling.

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

Anything already at one of these paths, including your own symlink, is **moved
aside** to `<name>.pre-dotfiles` first, never deleted (the convention Oh My Zsh
uses for `~/.zshrc.pre-oh-my-zsh`). `./uninstall.sh` puts it back. `~/.claude/settings.json` is
merged rather than replaced, keeping your own settings in it.

**If you use Claude Code,** note that the linked `~/.claude` files replace your
global instructions, agents, skills and hooks with the ones in `claude/`. Run
the installer with `--no-claude` to leave `~/.claude` untouched; nothing else
depends on it.

Nothing Linux-specific runs on macOS: no pacman or AUR packages.

## What the installer does on Linux

The same shared steps as macOS (Oh My Zsh, nvm, Neovim, tmux, Claude Code
unless `--no-claude`, `~/.config/dotfiles`), plus:

- Packages from `os/linux/pacman.txt` (`pacman -S --needed`) and
  `os/linux/aur.txt` (via `paru` or `yay`). Only the shared tools: no desktop.
- Kitty and Fastfetch, linked as on macOS.

The Hyprland desktop is a separate repository,
[kseeman/desktop](https://github.com/kseeman/desktop), installed on top of this
one with its own `install.sh`; see [Linux desktop](#linux-desktop).

## Layout

Shared configuration lives at the top level. Anything that genuinely differs
per platform lives under `os/<os>/`.

```
lib/os.sh             OS detection, shared by the installer and zsh
lib/install.sh        Installer helpers, shared by both installers
install.sh            Shared install steps; dispatches to the OS installer
zsh/                  Shared shell configuration
kitty/ fastfetch/     Config sources (linked per-OS)
tmux/                 Shared tmux config (clipboard bits in os/<os>/tmux.conf)
claude/               Claude Code harness (CLAUDE.md, agents, skills, hooks)
nvim/                 NvChad-based config with a multi-profile system
os/macos/             Brewfile, install steps, macOS-only zsh
os/linux/             pacman.txt, aur.txt, install steps, Linux-only zsh
```

`os/<os>/zsh/` is sourced *before* the shared `zsh/` files. The OS files own
what differs — package-manager paths, `NVM_SH`, `JAVA_HOME`, the `ls` color
flag — and the shared files build on those.

## Packages

Two parallel manifests, kept in sync by hand:

- macOS — `os/macos/Brewfile` (`brew bundle`)
- Linux — `os/linux/pacman.txt` (`pacman -S --needed`), plus
  `os/linux/aur.txt` for anything not in the official repos

Adding a cross-platform tool means adding it to both. The desktop's own
packages are in its repository's `packages/`, not here.

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

tmux uses the terminal's own palette. On a machine running the
[desktop](https://github.com/kseeman/desktop), the status bar instead follows
the active rice: the desktop writes `$XDG_CACHE_HOME/dotfiles/theme/tmux.conf`,
which `tmux.conf` sources last when it exists. Kitty and Neovim pick up the
same palette the same way.

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

`~/.config/dotfiles` is never tracked here. It holds everything local to a machine
or a project, so it is the one directory to back up:

```
~/.config/dotfiles/zsh/local.zsh            Machine-specific shell settings
~/.config/dotfiles/zsh/extensions/          Work/project shell extensions
~/.config/dotfiles/zsh/secrets/             Private environment variables
~/.config/dotfiles/tmux/sessionizer-paths   Extra project roots for the sessionizer
~/.config/dotfiles/tmux/profiles/<session>  nvim profile a project's session opens with
~/.config/dotfiles/tmux/layouts/<session>   Per-project window layout script
~/.config/dotfiles/nvim/local.lua           Machine-specific Neovim code
~/.config/dotfiles/nvim/projects/<repo>.lua Per-project Neovim settings
```

It contains secrets, so keep backups encrypted and never publish it.

## Linux desktop

The Hyprland desktop — bar, rices, lock screen, wallpaper, and the theming of
tmux, kitty and Neovim — lives in
[kseeman/desktop](https://github.com/kseeman/desktop). Install these dotfiles
first, then that repo's `install.sh`; it uses this repo's `lib/install.sh` and
themes the tools here by writing `$XDG_CACHE_HOME/dotfiles/theme/`. Nothing in
this repo needs it.
