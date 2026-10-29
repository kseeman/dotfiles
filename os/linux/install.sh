#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Linux installation steps
# -----------------------------------------------------------------------------
#
# Sourced (not executed) by ../../install.sh, so DOTFILES_DIR, DOTFILES_DISTRO,
# DRY_RUN, the lib/install.sh helpers and the resolved XDG_CONFIG / XDG_BIN are
# already defined here.
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
# Packages
# -----------------------------------------------------------------------------

install_pacman_manifest "$DOTFILES_DIR/os/linux/pacman.txt"
install_aur_manifest "$DOTFILES_DIR/os/linux/aur.txt"

# -----------------------------------------------------------------------------
# NVM location
# -----------------------------------------------------------------------------

# Arch's nvm package installs system-wide rather than cloning into ~/.nvm;
# matches os/linux/zsh/exports.zsh.
NVM_SH="/usr/share/nvm/nvm.sh"

# -----------------------------------------------------------------------------
# Links
# -----------------------------------------------------------------------------

# Called by the shared installer after the ~/.dotfiles symlink exists.
#
# The Hyprland desktop is not installed here: it is its own repository, put on
# top of this one by its own installer, and it themes kitty and the rest by
# writing $XDG_CACHE_HOME/dotfiles/theme/ for them to read.
os_link_configs() {
    # Kitty and Fastfetch are linked whether or not HyDE is present.
    #
    # They used to be skipped here, to leave the existing desktop untouched.
    # That skip is what made them the last things still themed by HyDE, and
    # removing HyDE would have taken the terminal's colours and the shell
    # banner's logo with it. Owning them now is what makes that removal a
    # non-event.
    #
    # Safe to take over: link_config moves whatever is there to
    # <name>.pre-dotfiles first, so HyDE's own files are kept rather than
    # overwritten, and neither program is session-specific -- the same terminal
    # config serves both sessions while both exist.
    info "Configuring Kitty..."

    run "mkdir -p '$XDG_CONFIG/kitty'"

    link_config \
        "$HOME/.dotfiles/kitty/kitty.conf" \
        "$XDG_CONFIG/kitty/kitty.conf"

    link_config \
        "$HOME/.dotfiles/kitty/theme.conf" \
        "$XDG_CONFIG/kitty/theme.conf"

    info "Configuring Fastfetch..."

    run "mkdir -p '$XDG_CONFIG/fastfetch'"

    link_config \
        "$HOME/.dotfiles/fastfetch/config.jsonc" \
        "$XDG_CONFIG/fastfetch/config.jsonc"
}
