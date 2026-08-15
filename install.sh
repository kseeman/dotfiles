#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# Set by the OS-specific installer sourced below.
NVM_SH=""

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

info() {
    echo ""
    echo "==> $1"
}

run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] $*"
    else
        eval "$@"
    fi
}

link_config() {
    local source="$1"
    local target="$2"

    if [[ ! -e "$source" ]]; then
        echo "Missing source: $source"
        return
    fi

    if [[ -e "$target" && ! -L "$target" ]]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"

        info "Backing up existing $(basename "$target")"
        run "mv '$target' '$backup'"
    fi

    run "ln -sfn '$source' '$target'"
}

# -----------------------------------------------------------------------------
# Validate environment
# -----------------------------------------------------------------------------

info "Installing dotfiles from:"
echo "$DOTFILES_DIR"

if [[ "$DRY_RUN" == true ]]; then
    echo "Running in dry-run mode. No changes will be made."
fi

source "$DOTFILES_DIR/lib/os.sh"

DOTFILES_OS="$(dotfiles_detect_os)"
DOTFILES_DISTRO="$(dotfiles_detect_distro)"

OS_DIR="$DOTFILES_DIR/os/$DOTFILES_OS"

if [[ ! -d "$OS_DIR" ]]; then
    echo "Unsupported operating system: $(uname -s)"
    echo "Add an os/<name> directory to support it."
    exit 1
fi

echo "Detected: $DOTFILES_OS${DOTFILES_DISTRO:+ ($DOTFILES_DISTRO)}"

# -----------------------------------------------------------------------------
# OS-specific setup
# -----------------------------------------------------------------------------

# Sourced rather than executed so it inherits DRY_RUN and the helpers above,
# and can hand NVM_SH plus an optional os_link_configs() hook back to the
# shared steps below.
info "Running $DOTFILES_OS setup..."

source "$OS_DIR/install.sh"

# -----------------------------------------------------------------------------
# Dependency check
# -----------------------------------------------------------------------------

if [[ -x "$DOTFILES_DIR/zsh/dependencies.zsh" ]]; then
    info "Checking dependencies..."

    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] $DOTFILES_DIR/zsh/dependencies.zsh"
    else
        "$DOTFILES_DIR/zsh/dependencies.zsh"
    fi
fi

# -----------------------------------------------------------------------------
# NVM
# -----------------------------------------------------------------------------

info "Configuring NVM..."

# Node versions live here on every OS; only the location of nvm.sh differs,
# which is why the OS installer sets NVM_SH.
run "mkdir -p '$HOME/.nvm'"

if [[ -z "$NVM_SH" ]]; then
    echo "No NVM_SH set by the $DOTFILES_OS installer, skipping Node setup."
elif [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] source $NVM_SH"
    echo "[dry-run] nvm install --lts"
    echo "[dry-run] nvm alias default lts/*"
elif [[ ! -s "$NVM_SH" ]]; then
    echo "nvm.sh not found at $NVM_SH, skipping Node setup."
else
    export NVM_DIR="$HOME/.nvm"

    source "$NVM_SH"

    if ! nvm ls --lts &>/dev/null; then
        echo "Installing Node LTS..."

        nvm install --lts
        nvm alias default 'lts/*'
    else
        echo "Node LTS already installed."
    fi
fi

# -----------------------------------------------------------------------------
# Oh My Zsh
# -----------------------------------------------------------------------------

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."

    run 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
else
    info "Oh My Zsh already installed."
fi

# -----------------------------------------------------------------------------
# Oh My Zsh plugins
# -----------------------------------------------------------------------------

info "Installing Oh My Zsh plugins..."

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

install_omz_plugin() {
    local name="$1"
    local repo="$2"

    if [[ ! -d "$ZSH_CUSTOM/plugins/$name" ]]; then
        run "git clone '$repo' '$ZSH_CUSTOM/plugins/$name'"
    else
        echo "Plugin already installed: $name"
    fi
}

install_omz_plugin \
    "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions"

install_omz_plugin \
    "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting"

# -----------------------------------------------------------------------------
# Dotfiles symlink
# -----------------------------------------------------------------------------

info "Creating ~/.dotfiles symlink..."

run "ln -sfn '$DOTFILES_DIR' '$HOME/.dotfiles'"

# -----------------------------------------------------------------------------
# Zsh configuration
# -----------------------------------------------------------------------------

info "Linking ~/.zshrc..."

link_config \
    "$HOME/.dotfiles/zsh/zshrc" \
    "$HOME/.zshrc"

# -----------------------------------------------------------------------------
# Neovim configuration
# -----------------------------------------------------------------------------

# Shared: nvim/ is already cross-platform via profile-manager.lua, so the whole
# directory is linked on every OS.
info "Linking ~/.config/nvim..."

run "mkdir -p '$HOME/.config'"

link_config \
    "$HOME/.dotfiles/nvim" \
    "$HOME/.config/nvim"

# -----------------------------------------------------------------------------
# tmux configuration
# -----------------------------------------------------------------------------

# The config itself is shared; only clipboard integration differs per platform.
# The OS fragment is linked to os.conf, which tmux.conf sources at its end.
#
# The -f test reads the repo path rather than ~/.dotfiles so it still evaluates
# correctly during a dry run, when that symlink may not exist yet.
info "Linking tmux configuration..."

run "mkdir -p '$HOME/.config/tmux'"

link_config \
    "$HOME/.dotfiles/tmux/tmux.conf" \
    "$HOME/.config/tmux/tmux.conf"

if [[ -f "$OS_DIR/tmux.conf" ]]; then
    link_config \
        "$HOME/.dotfiles/os/$DOTFILES_OS/tmux.conf" \
        "$HOME/.config/tmux/os.conf"
fi

# -----------------------------------------------------------------------------
# OS-specific configuration links
# -----------------------------------------------------------------------------

# Which desktop configs get linked is itself platform-specific: on macOS this
# repo owns Kitty and Fastfetch, while on a Linux desktop those directories may
# already belong to the desktop environment. Each OS installer decides, and runs
# here — after the ~/.dotfiles symlink the link targets depend on.
if declare -F os_link_configs >/dev/null; then
    os_link_configs
fi

# -----------------------------------------------------------------------------
# User configuration reminder
# -----------------------------------------------------------------------------

info "Checking ~/.userconfig..."

if [[ ! -d "$HOME/.userconfig" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] create ~/.userconfig structure"
    else
        mkdir -p "$HOME/.userconfig/zsh/extensions"
        mkdir -p "$HOME/.userconfig/zsh/secrets"

        cat > "$HOME/.userconfig/README.md" <<EOF
# Local User Configuration

This directory is intentionally not managed by dotfiles.

Use:

~/.userconfig/zsh/local.zsh
    Machine-specific configuration

~/.userconfig/zsh/extensions/
    Work/project shell extensions

~/.userconfig/zsh/secrets/
    Private environment variables and credentials

Do not commit this directory.
EOF

        echo ""
        echo "Created ~/.userconfig structure."
        echo "Add private or machine-specific configuration there."
    fi
else
    echo "~/.userconfig already exists."
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

echo ""
echo "======================================"
echo " Dotfiles installation complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal"
echo "  2. Open Kitty for the full terminal experience"
echo "  3. Add machine-specific settings to ~/.userconfig"
echo ""
