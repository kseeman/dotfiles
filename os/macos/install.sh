#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# macOS installation steps
# -----------------------------------------------------------------------------
#
# Sourced (not executed) by ../../install.sh, so DOTFILES_DIR, DRY_RUN and the
# info()/run() helpers are already defined here.
#
# Contract with the shared installer:
#   - install the packages this OS needs
#   - set NVM_SH to this OS's nvm.sh, which the shared NVM step then sources

# -----------------------------------------------------------------------------
# Validate environment
# -----------------------------------------------------------------------------

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "This installer expects an Apple Silicon Mac (found $(uname -m))."
    exit 1
fi

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------

if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."

    run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

if [[ ! -x "/opt/homebrew/bin/brew" ]]; then
    echo "Homebrew was not found at /opt/homebrew/bin/brew"
    echo "This installer expects Apple Silicon Homebrew."
    exit 1
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------

if [[ -f "$DOTFILES_DIR/os/macos/Brewfile" ]]; then
    info "Installing Homebrew packages..."

    run "brew bundle --file '$DOTFILES_DIR/os/macos/Brewfile'"
else
    echo "No Brewfile found, skipping Homebrew packages."
fi

# -----------------------------------------------------------------------------
# NVM location
# -----------------------------------------------------------------------------

# Homebrew keeps nvm's scripts in the keg; matches os/macos/zsh/exports.zsh.
NVM_SH="/opt/homebrew/opt/nvm/nvm.sh"

# -----------------------------------------------------------------------------
# Configuration links
# -----------------------------------------------------------------------------

# Called by the shared installer after the ~/.dotfiles symlink exists. On macOS
# this repo is the sole owner of the Kitty and Fastfetch configuration, so both
# are linked outright.
os_link_configs() {
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
