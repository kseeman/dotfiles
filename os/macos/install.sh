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
# netcoredbg (Apple Silicon)
# -----------------------------------------------------------------------------

# The .NET debugger, installed outside Mason because Mason ships the wrong
# architecture here.
#
# mason-registry pins netcoredbg to 3.1.3-1062 and maps both darwin targets to
# netcoredbg-osx-amd64.tar.gz, because 3.1.3 had no osx-arm64 asset. On an arm64
# Mac that yields an x86_64 binary running under Rosetta, which cannot load the
# arm64 DAC out of an arm64 debuggee: every attach fails at `configurationDone`
# with 0x80131c3c (CORDBG_E_DEBUG_COMPONENT_MISSING). It runs and reports its
# version normally, so nothing short of a real attach reveals the problem.
#
# 3.2.0-1092 ships netcoredbg-osx-arm64.zip. It goes to ~/.local/opt rather than
# into the Mason package directory, which :MasonUpdate would clobber;
# nvim/lua/configs/dap.lua prefers this path when it exists and otherwise falls
# back to Mason. This whole block can go once mason-registry bumps the pin and
# splits the darwin targets — remove ~/.local/opt/netcoredbg to revert.
#
# The existence guard: this is a pinned version, so re-running the installer
# should not re-download it. Delete the directory to force an upgrade.

NETCOREDBG_VERSION="3.2.0-1092"
NETCOREDBG_DIR="$HOME/.local/opt/netcoredbg"

if [[ -x "$NETCOREDBG_DIR/netcoredbg" ]]; then
    info "netcoredbg already installed, skipping."
else
    info "Installing netcoredbg $NETCOREDBG_VERSION (arm64)..."

    NETCOREDBG_URL="https://github.com/Samsung/netcoredbg/releases/download/${NETCOREDBG_VERSION}/netcoredbg-osx-arm64.zip"

    run "mkdir -p '$HOME/.local/opt'"
    run "curl -fsSL -o '$HOME/.local/opt/netcoredbg.zip' '$NETCOREDBG_URL'"
    run "rm -rf '$NETCOREDBG_DIR' '$HOME/.local/opt/__MACOSX'"
    run "unzip -q '$HOME/.local/opt/netcoredbg.zip' -d '$HOME/.local/opt'"
    run "rm -rf '$HOME/.local/opt/netcoredbg.zip' '$HOME/.local/opt/__MACOSX'"

    # Both steps are required for a downloaded debugger. Quarantine is only set
    # when the archive arrives via a Gatekeeper-aware app rather than curl, so
    # the first is a no-op here but matters for a hand-downloaded copy. The
    # ad-hoc signature is what lets the binary take the debugging entitlement.
    run "xattr -dr com.apple.quarantine '$NETCOREDBG_DIR' 2>/dev/null || true"
    run "codesign --force --sign - '$NETCOREDBG_DIR/netcoredbg' '$NETCOREDBG_DIR/libdbgshim.dylib'"
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
