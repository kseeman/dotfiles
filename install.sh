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

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------

if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."

    run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

if [[ ! -x "/opt/homebrew/bin/brew" ]]; then
    echo "Homebrew was not found at /opt/homebrew/bin/brew"
    echo "This installer expects an Apple Silicon Mac."
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

if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    backup="$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"

    info "Backing up existing ~/.zshrc"
    run "mv '$HOME/.zshrc' '$backup'"
fi

run "ln -sfn '$DOTFILES_DIR/zsh/zshrc' '$HOME/.zshrc'"

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
# Private configuration reminder
# -----------------------------------------------------------------------------

if [[ ! -d "$HOME/.userconfig/zsh" ]]; then
    echo ""
    echo "Reminder:"
    echo "  Create ~/.userconfig/zsh for machine-specific configuration."
    echo ""
    echo "Suggested structure:"
    echo "  ~/.userconfig/zsh/"
    echo "  ├── local.zsh"
    echo "  ├── extensions/"
    echo "  └── secrets/"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

echo ""
echo "======================================"
echo " Dotfiles installation complete!"
echo "======================================"
