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

# -----------------------------------------------------------------------------
# Lua desktop session
# -----------------------------------------------------------------------------

# Installs a second login session that runs this repo's Lua Hyprland config,
# leaving the existing one alone. Both appear at the login screen, so switching
# between them is a choice made there, and removing the entry below reverts to
# whatever was there before with nothing else touched.
#
# The config is named with --config rather than by exporting HYPRLAND_CONFIG.
# HyDE assigns that variable unconditionally in its own uwsm env fragment, so
# using it would mean winning an ordering contest inside uwsm's env.d for a file
# this repo does not own. --config is read in preference to the variable
# (verified on 0.56.2) and needs no HyDE file edited.
#
# The entry is a template because the path must be absolute: Desktop Entry
# field codes have nothing for the home directory, and /usr/share/wayland-
# sessions is root-owned and shared between users.
SESSION_ENTRY="/usr/share/wayland-sessions/hyprland-dotfiles.desktop"

install_desktop_session() {
    local desktop_dir="$DOTFILES_DIR/os/linux/desktop"
    local template="$desktop_dir/session/hyprland-dotfiles.desktop.in"
    local init_lua="$HOME/.dotfiles/os/linux/desktop/init.lua"

    [[ -f "$template" ]] || return 0

    # A config that does not parse must never reach the login screen, where the
    # only way to read the error is from another machine. Hyprland parses it
    # without starting a session, so this costs nothing and catches everything
    # the compositor would have refused.
    info "Verifying the Lua Hyprland configuration..."

    if ! "$desktop_dir/verify-config.sh" "$desktop_dir/init.lua"; then
        echo "Refusing to install the session entry while the config has errors."
        return 1
    fi

    # Verifying the config proved the compositor would accept it and proved
    # nothing about the command line that launches it: a malformed Exec fails
    # inside uwsm's argument parsing, before Hyprland is reached, and a display
    # manager reports that as a failed login rather than a bad command. A dry
    # run writes and starts nothing, so it is safe to do from inside a running
    # session, and it is the only check that covers the Exec line itself.
    local exec_line dry_run_line

    # Read from the template and substituted exactly as the entry will be, so
    # this tests the line the display manager will actually run. Rebuilding an
    # equivalent command here would let the two drift, and a check that passes
    # while the installed entry is broken is worse than no check.
    exec_line="$(sed -n 's/^Exec=//p' "$template" | sed "s|@INIT_LUA@|$init_lua|")"

    if command -v uwsm &> /dev/null && [[ "$exec_line" == uwsm\ start\ * ]]; then
        info "Checking the session command line..."

        dry_run_line="${exec_line/uwsm start/uwsm start -n}"

        if ! eval "$dry_run_line" &> /dev/null; then
            echo "uwsm rejected the session command line:"
            eval "$dry_run_line" 2>&1 | sed 's/^/    /'
            echo ""
            echo "Refusing to install a session entry that cannot start."
            return 1
        fi

        echo "    uwsm accepts it"
    fi

    info "Installing the 'Hyprland (dotfiles)' session..."

    # Needs root: session entries are system-wide. Written via a temporary file
    # so a failed substitution cannot leave a half-written entry that SDDM would
    # still offer.
    local staged="${TMPDIR:-/tmp}/hyprland-dotfiles.desktop.$$"

    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] install $template -> $SESSION_ENTRY (INIT_LUA=$init_lua)"
        return 0
    fi

    sed "s|@INIT_LUA@|$init_lua|" "$template" > "$staged"

    sudo install -Dm644 "$staged" "$SESSION_ENTRY"
    rm -f "$staged"

    echo "    Log out and pick 'Hyprland (dotfiles)' to try it."
    echo "    The existing session is untouched and still the one to fall back to."
}

# -----------------------------------------------------------------------------
# Wallbash templates
# -----------------------------------------------------------------------------

# Templates that let HyDE recolour extra applications from the current
# wallpaper. Each .dcol declares its own output path on its header line; the
# tmux one writes ~/.config/tmux/wallbash.conf, which tmux.conf sources.
#
# Copied rather than linked: wallbash finds templates with
# `find -H … -type f`, which does not follow symlinks, so a symlinked template
# is invisible — the same constraint as theme wallpapers. Re-run the installer
# after editing a template.
install_wallbash_templates() {
    local src="$DOTFILES_DIR/os/linux/wallbash"
    local dest="$HOME/.config/hyde/wallbash/always"

    [[ -d "$src" ]] || return 0

    if ! compgen -G "$src/*.dcol" >/dev/null; then
        return 0
    fi

    info "Installing wallbash templates..."

    run "mkdir -p '$dest'"
    run "cp -u '$src/'*.dcol '$dest/'"

    echo "Applied on the next theme or wallpaper change."
}

# The bar reads its colours from a generated JSON file rather than from
# anything tracked, so a fresh machine needs it written once before the first
# login. Without it the vendored pill falls back to its own warm palette --
# usable, but not this scheme.
#
# Cheap and idempotent, so it runs every install: it is also how a palette.lua
# edit reaches the bar.
# The pill shells out to helpers it expects at ~/.config/hypr/scripts. A whole
# directory rather than file-by-file, so a script added to the repo is live
# without touching the installer.
#
# ~/.config/hypr is otherwise HyDE's, but it ships no scripts/ of its own, so
# nothing is displaced. Worth remembering that HyDE deploys with `cp -rf`,
# which writes *through* a symlink -- if it ever grows a scripts/ directory,
# this link is how its contents would land in the repo.
install_pill_scripts() {
    local scripts="$DOTFILES_DIR/os/linux/desktop/quickshell/scripts"

    [[ -d "$scripts" ]] || return 0

    link_config "$scripts" "$HOME/.config/hypr/scripts"
}

# Generates every config that carries a colour, from lib/palette.lua. The
# session does this at login too; doing it here means a fresh machine has them
# before its first login rather than one login later.
install_theme() {
    local render="$DOTFILES_DIR/os/linux/desktop/render-theme.lua"

    [[ -x "$render" ]] || return 0

    info "Rendering theme files from the palette..."

    run "lua '$render' --verbose"
}

# The bar ignores generated colours entirely while paletteMode is "static",
# which is its default, so this has to run once before the colours mean
# anything. Idempotent, so it simply runs every install.
install_pill_flags() {
    local script="$DOTFILES_DIR/os/linux/desktop/quickshell/pill-flags.sh"

    [[ -x "$script" ]] || return 0

    info "Setting the bar to use generated colours..."

    run "$script"
}

# Called by the shared installer after the ~/.dotfiles symlink exists.
os_link_configs() {
    # Additive and HyDE-independent: these are user-tier files that HyDE seeds
    # but never rewrites, so they link whether or not HyDE is present.
    install_hypr_configs

    # Also additive: a second session entry alongside whatever is already
    # installed, never a replacement for it.
    install_desktop_session

    # All three write generated files outside the repo, so they are safe
    # alongside HyDE.
    install_theme

    install_pill_flags

    install_pill_scripts

    if hyde_owns_desktop_configs; then
        # Additive: theme directories HyDE doesn't own and won't overwrite, so
        # they install even though the desktop configs below are left alone.
        install_hyde_themes

        # Wallbash only exists with HyDE, so this belongs in this branch.
        install_wallbash_templates

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
