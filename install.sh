#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

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

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "This installer currently supports macOS only."
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "This installer expects an Apple Silicon Mac."
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
# Brew packages
# -----------------------------------------------------------------------------

if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    info "Installing Homebrew packages..."

    run "brew bundle --file '$DOTFILES_DIR/Brewfile'"
else
    echo "No Brewfile found, skipping Homebrew packages."
fi

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

mkdir -p "$HOME/.nvm"

if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] source $(brew --prefix nvm)/nvm.sh"
    echo "[dry-run] nvm install --lts"
    echo "[dry-run] nvm alias default lts/*"
else
    export NVM_DIR="$HOME/.nvm"

    source "$(brew --prefix nvm)/nvm.sh"

    if ! nvm ls --lts &>/dev/null; then
        echo "Installing Node LTS..."

        nvm install --lts
        nvm alias default lts/*
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
# Kitty configuration
# -----------------------------------------------------------------------------

info "Configuring Kitty..."

mkdir -p "$HOME/.config/kitty"

link_config \
    "$HOME/.dotfiles/kitty/kitty.conf" \
    "$HOME/.config/kitty/kitty.conf"

link_config \
    "$HOME/.dotfiles/kitty/theme.conf" \
    "$HOME/.config/kitty/theme.conf"

# -----------------------------------------------------------------------------
# Fastfetch configuration
# -----------------------------------------------------------------------------

info "Configuring Fastfetch..."

mkdir -p "$HOME/.config/fastfetch"

link_config \
    "$HOME/.dotfiles/fastfetch/config.jsonc" \
    "$HOME/.config/fastfetch/config.jsonc"

# -----------------------------------------------------------------------------
# User configuration reminder
# -----------------------------------------------------------------------------

info "Checking ~/.userconfig..."

if [[ ! -d "$HOME/.userconfig" ]]; then
    mkdir -p "$HOME/.userconfig/zsh/extensions"
    mkdir -p "$HOME/.userconfig/zsh/secrets"

    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] create ~/.userconfig structure"
    else
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
    fi

    echo ""
    echo "Created ~/.userconfig structure."
    echo "Add private or machine-specific configuration there."
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
