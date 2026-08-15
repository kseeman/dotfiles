#!/usr/bin/env zsh

# Run standalone by install.sh, so it works out its own paths and loads the
# OS-specific exports itself — otherwise Homebrew-installed tools would look
# missing on macOS, and NVM_SH would be unset on both platforms.

DOTFILES_ZSH_DIR="${0:A:h}"
DOTFILES_DIR="${DOTFILES_ZSH_DIR:h}"

source "$DOTFILES_DIR/lib/os.sh"

DOTFILES_OS="$(dotfiles_detect_os)"
DOTFILES_DISTRO="$(dotfiles_detect_distro)"

OS_EXPORTS="$DOTFILES_DIR/os/$DOTFILES_OS/zsh/exports.zsh"

[[ -r "$OS_EXPORTS" ]] && source "$OS_EXPORTS"

missing=()

check_command() {
    if ! command -v "$1" &>/dev/null; then
        missing+=("$1")
    fi
}

# nvm is a shell function rather than a binary, so `command -v` won't find it.
# NVM_SH is set per-OS; see os/<os>/zsh/exports.zsh.
check_nvm() {
    if [[ -z "${NVM_SH:-}" || ! -s "$NVM_SH" ]]; then
        missing+=("nvm")
    fi
}

echo "Checking shell dependencies for $DOTFILES_OS${DOTFILES_DISTRO:+ ($DOTFILES_DISTRO)}..."

# -----------------------------------------------------------------------------
# Shared
# -----------------------------------------------------------------------------

check_command git
check_command nvim
check_command node
check_command pnpm
check_command zoxide
check_command fastfetch
check_command bat
check_command rg

check_nvm

# -----------------------------------------------------------------------------
# Platform
# -----------------------------------------------------------------------------

case "$DOTFILES_OS" in
    macos)
        check_command brew
        ;;
    linux)
        check_command pacman
        ;;
esac

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------

if (( ${#missing[@]} > 0 )); then
    echo ""
    echo "Missing dependencies:"

    for dep in "${missing[@]}"; do
        echo "  - $dep"
    done

    echo ""

    case "$DOTFILES_OS" in
        macos)
            echo "Install them with: brew bundle --file os/macos/Brewfile"
            ;;
        linux)
            echo "Install them with: sudo pacman -S --needed \$(grep -v '^#' os/linux/pacman.txt)"
            ;;
        *)
            echo "Install missing tools before using this dotfiles setup."
            ;;
    esac

    exit 1
fi

echo "All dependencies installed."
