# dotfiles

Personal Neovim, zsh, and terminal configuration for macOS (Apple Silicon) and
Arch-based Linux.

## Install

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # preview; makes no changes
./install.sh
```

The installer detects the platform and runs the matching setup from `os/`.

## Layout

Shared configuration lives at the top level. Anything that genuinely differs
per platform lives under `os/<os>/`.

```
lib/os.sh          OS detection, shared by the installer and zsh
install.sh         Shared install steps; dispatches to the OS installer
zsh/               Shared shell configuration
kitty/ fastfetch/  Config sources (linked per-OS — see below)
nvim/              NvChad-based config with a multi-profile system
os/macos/          Brewfile, install steps, macOS-only zsh
os/linux/          pacman.txt, aur.txt, install steps, Linux-only zsh
os/linux/hypr/     User-tier Hyprland config (keybinds, window rules, prefs)
os/linux/hyde-themes/ Custom HyDE themes, installed when HyDE is present
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

## Hyprland / HyDE

HyDE is a **prerequisite**, not something this installer sets up — install it
first, then run `./install.sh`. Doing it in the other order links this repo's
Kitty and Fastfetch configs into paths HyDE also wants; re-running the installer
afterwards corrects it.

```sh
git clone https://github.com/HyDE-Project/HyDE ~/HyDE
# run HyDE's own installer, then:
./install.sh
```

The repo tracks the user-tier Hyprland files (`os/linux/hypr/`) and any custom
themes, and leaves everything HyDE generates alone. `monitors.conf` and
`nvidia.conf` are intentionally not tracked — they are hardware-specific.

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

## Desktop configuration

On macOS this repo owns `~/.config/kitty` and `~/.config/fastfetch` and links
them directly.

On Linux, if HyDE (the Hyprland desktop) is detected, both directories are left
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

## Machine-specific configuration

`~/.userconfig` is never tracked here, and is sourced at the end of shell
startup:

```
~/.userconfig/zsh/local.zsh       Machine-specific settings
~/.userconfig/zsh/extensions/     Work/project shell extensions
~/.userconfig/zsh/secrets/        Private environment variables
```
