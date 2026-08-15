# -----------------------------------------------------------------------------
# Dotfiles
# -----------------------------------------------------------------------------

# Absolute path to the directory containing this file
export DOTFILES_ZSH_DIR="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
export DOTFILES_DIR="$(cd -- "$DOTFILES_ZSH_DIR/.." && pwd)"

# -----------------------------------------------------------------------------
# Platform
# -----------------------------------------------------------------------------

# Same detection install.sh uses, so a shell and an install always agree on
# which os/<name> directory applies.
source "$DOTFILES_DIR/lib/os.sh"

export DOTFILES_OS="$(dotfiles_detect_os)"
export DOTFILES_DISTRO="$(dotfiles_detect_distro)"

# -----------------------------------------------------------------------------
# Oh My Zsh
# -----------------------------------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins. Built up in stages because macos/brew only apply on one platform and
# zsh-syntax-highlighting has to stay last.
plugins=(git)

if [[ "$DOTFILES_OS" == "macos" ]]; then
    plugins+=(macos brew)
fi

plugins+=(
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Initialize Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# -----------------------------------------------------------------------------
# Shared user configuration
# -----------------------------------------------------------------------------

source "$DOTFILES_ZSH_DIR/init.zsh"
