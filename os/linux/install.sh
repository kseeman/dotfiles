#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Linux installation steps
# -----------------------------------------------------------------------------
#
# Sourced (not executed) by ../../install.sh, so DOTFILES_DIR, DOTFILES_DISTRO,
# DRY_RUN and the info()/run() helpers are already defined here.
#
# Contract with the shared installer:
#   - install the packages this OS needs
#   - set NVM_SH to this OS's nvm.sh, which the shared NVM step then sources

# -----------------------------------------------------------------------------
# Validate environment
# -----------------------------------------------------------------------------

if [[ "$DOTFILES_DISTRO" != "arch" ]]; then
    echo "Unsupported Linux distribution: ${DOTFILES_DISTRO:-unknown}"
    echo "Only Arch-based distributions are supported so far."
    echo "Add os/linux support for your package manager to continue."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    echo "pacman was not found, but the distro reports as Arch-based."
    exit 1
fi

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Manifests are one package per line with # comments and blank lines allowed;
# this flattens them to a space-separated list.
read_manifest() {
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1" | tr '\n' ' '
}

# -----------------------------------------------------------------------------
# Repository packages
# -----------------------------------------------------------------------------

PACMAN_MANIFEST="$DOTFILES_DIR/os/linux/pacman.txt"

if [[ -f "$PACMAN_MANIFEST" ]]; then
    packages="$(read_manifest "$PACMAN_MANIFEST")"

    if [[ -n "${packages// /}" ]]; then
        info "Installing pacman packages..."

        # --needed skips anything already present, so this is safe to re-run.
        # Left interactive on purpose: pacman shows what it's about to do.
        run "sudo pacman -S --needed $packages"
    fi
else
    echo "No pacman.txt found, skipping repository packages."
fi

# -----------------------------------------------------------------------------
# AUR packages
# -----------------------------------------------------------------------------

AUR_MANIFEST="$DOTFILES_DIR/os/linux/aur.txt"

if [[ -f "$AUR_MANIFEST" ]]; then
    aur_packages="$(read_manifest "$AUR_MANIFEST")"

    if [[ -n "${aur_packages// /}" ]]; then
        if command -v paru &>/dev/null; then
            aur_helper="paru"
        elif command -v yay &>/dev/null; then
            aur_helper="yay"
        else
            aur_helper=""
        fi

        if [[ -n "$aur_helper" ]]; then
            info "Installing AUR packages with $aur_helper..."

            run "$aur_helper -S --needed $aur_packages"
        else
            echo "No AUR helper (paru/yay) found, skipping: $aur_packages"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# NVM location
# -----------------------------------------------------------------------------

# Arch's nvm package installs system-wide rather than cloning into ~/.nvm;
# matches os/linux/zsh/exports.zsh.
NVM_SH="/usr/share/nvm/nvm.sh"

# -----------------------------------------------------------------------------
# Configuration links
# -----------------------------------------------------------------------------

# HyDE (the Hyprland desktop) generates ~/.config/kitty and ~/.config/fastfetch
# and rewrites them on every theme switch: kitty.conf does `include hyde.conf`,
# theme.conf is regenerated, and the Fastfetch logo comes from a theme-aware
# `fastfetch.sh logo` call. Linking this repo's versions over the top would
# break theme switching and replace the HyDE Fastfetch design.
hyde_owns_desktop_configs() {
    command -v hyde-shell &>/dev/null && return 0
    command -v hydectl &>/dev/null && return 0
    [[ -f "$HOME/.config/kitty/hyde.conf" ]] && return 0

    return 1
}

# -----------------------------------------------------------------------------
# HyDE themes
# -----------------------------------------------------------------------------

# Files a theme may contain that are safe to symlink. HyDE reads each by path
# (`-f`/`-r`), which follows symlinks, so these stay linked to the repo and
# remain live-editable. Anything not listed is ignored.
HYDE_THEME_LINKABLE=(
    hypr.theme
    kitty.theme
    waybar.theme
    rofi.theme
    theme.dcol
    animations.theme
    hyprlock.theme
    swaync.theme
    .sort
)

# Installs every directory under os/linux/hyde-themes/ as a HyDE theme. The
# directory name *is* the theme name — that's how HyDE identifies a theme — so
# adding a theme means adding a directory and renaming one means `git mv`.
#
# The mix of symlinks and copies below is forced by HyDE's discovery, which uses
# `find -H`. -H does not follow symlinks found during traversal, so a symlink is
# `-type l` — never `-type d` or `-type f`:
#
#   get_themes()   find -H … -maxdepth 1 -type d   a symlinked theme directory
#                                                  is invisible, and the theme
#                                                  silently never appears
#   get_hashmap()  find -H … -type f               symlinked images are
#                                                  invisible; a theme with no
#                                                  wallpaper is skipped entirely
install_hyde_themes() {
    local themes_dir="$DOTFILES_DIR/os/linux/hyde-themes"
    local link_base="$HOME/.dotfiles/os/linux/hyde-themes"
    local theme_path name src dest file

    [[ -d "$themes_dir" ]] || return 0

    for theme_path in "$themes_dir"/*/; do
        [[ -d "$theme_path" ]] || continue

        name="$(basename "$theme_path")"
        src="$link_base/$name"
        dest="$HOME/.config/hyde/themes/$name"

        info "Installing HyDE theme '$name'..."

        # Both must be real directories, per the note above.
        run "mkdir -p '$dest/wallpapers'"

        for file in "${HYDE_THEME_LINKABLE[@]}"; do
            if [[ -e "$theme_path/$file" ]]; then
                link_config "$src/$file" "$dest/$file"
            fi
        done

        if [[ -d "$theme_path/kvantum" ]]; then
            link_config "$src/kvantum" "$dest/kvantum"
        fi

        # Copied, not linked. Re-run the installer after adding a wallpaper.
        if compgen -G "$theme_path/wallpapers/*" >/dev/null; then
            run "cp -u '$src/wallpapers/'* '$dest/wallpapers/'"
        fi

        # HyDE writes wall.set and wall.*.png into $dest as wallpapers change.
        # Since $dest is a real directory, that state never reaches the repo.
        echo "Switch to it with: hydectl theme set '$name'"
    done
}

# -----------------------------------------------------------------------------
# Hyprland user configuration
# -----------------------------------------------------------------------------

# User-tier Hyprland files. HyDE never rewrites these — its generated output goes
# to ~/.config/hypr/themes/ instead — so they are safe to own here.
#
# Deliberately excluded, and they must stay that way:
#
#   monitors.conf     generated by nwg-displays; names physical outputs
#   workspaces.conf   generated by nwg-displays; pins workspaces to those
#                     same outputs (monitor:DP-1, monitor:DP-2)
#   nvidia.conf       hardware-specific
#
# All of them describe *this* machine's hardware, so they would be wrong on any
# other one, and the nwg-displays pair is regenerated by that tool — tracking
# them means fighting it on every display rearrangement.
HYPR_USER_CONFIGS=(
    userprefs.conf
    keybindings.conf
    windowrules.conf
)

# Note on precedence: hyprland.conf sources userprefs.conf last, so anything set
# there outranks the active theme. Keep structure and behaviour here, and leave
# colors/gaps/rounding/blur to the theme, or theme switching will look broken.
install_hypr_configs() {
    local src="$HOME/.dotfiles/os/linux/hypr"
    local dest="$HOME/.config/hypr"
    local file

    [[ -d "$DOTFILES_DIR/os/linux/hypr" ]] || return 0

    info "Linking Hyprland user configuration..."

    # Created rather than required: on a fresh machine where Hyprland has never
    # run, ~/.config/hypr may not exist yet, and skipping here would be silent.
    # Without HyDE these files are linked but inert — Hyprland's own default
    # hyprland.conf doesn't source them.
    run "mkdir -p '$dest'"

    for file in "${HYPR_USER_CONFIGS[@]}"; do
        if [[ -e "$DOTFILES_DIR/os/linux/hypr/$file" ]]; then
            link_config "$src/$file" "$dest/$file"
        fi
    done
}

# Called by the shared installer after the ~/.dotfiles symlink exists.
os_link_configs() {
    # Additive and HyDE-independent: these are user-tier files that HyDE seeds
    # but never rewrites, so they link whether or not HyDE is present.
    install_hypr_configs

    if hyde_owns_desktop_configs; then
        # Additive: theme directories HyDE doesn't own and won't overwrite, so
        # they install even though the desktop configs below are left alone.
        install_hyde_themes

        info "Skipping Kitty and Fastfetch configuration..."

        echo "HyDE manages ~/.config/kitty and ~/.config/fastfetch here."
        echo "Both left untouched to preserve the existing Hyprland setup."
        echo ""
        echo "The shell still runs the Fastfetch banner on startup; it just"
        echo "renders with HyDE's config rather than this repo's."

        return
    fi

    # No HyDE here, so this repo owns Kitty and Fastfetch. The HyDE theme is
    # deliberately not installed — nothing would consume it.
    info "Configuring Kitty..."

    run "mkdir -p '$HOME/.config/kitty'"

    link_config \
        "$HOME/.dotfiles/kitty/kitty.conf" \
        "$HOME/.config/kitty/kitty.conf"

    link_config \
        "$HOME/.dotfiles/kitty/theme.conf" \
        "$HOME/.config/kitty/theme.conf"

    info "Configuring Fastfetch..."

    run "mkdir -p '$HOME/.config/fastfetch'"

    link_config \
        "$HOME/.dotfiles/fastfetch/config.jsonc" \
        "$HOME/.config/fastfetch/config.jsonc"
}
