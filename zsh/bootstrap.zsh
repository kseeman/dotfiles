# -----------------------------------------------------------------------------
# Dotfiles
# -----------------------------------------------------------------------------

# Absolute path to the directory containing this file
export DOTFILES_ZSH_DIR="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"

# -----------------------------------------------------------------------------
# Oh My Zsh
# -----------------------------------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
  git
  macos
  brew
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Initialize Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# -----------------------------------------------------------------------------
# Shared user configuration
# -----------------------------------------------------------------------------

source "$DOTFILES_ZSH_DIR/init.zsh"
