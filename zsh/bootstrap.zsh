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

# Oh My Zsh may already be running. When ZDOTDIR is redirected -- see
# link_redirected_zshrc in install.sh -- this file is sourced from the end of
# someone else's zshrc, and that zshrc has usually already loaded Oh My Zsh with
# a plugin list of its own.
#
# ZSH_CACHE_DIR is what says so: Oh My Zsh sets it, and nothing else does.
#
# Sourcing oh-my-zsh.sh a second time would re-run compinit and rebuild the
# completion dump on every shell, so the plugins it did not load are sourced
# directly instead -- which is all its plugin loader does for these two.
# zsh-syntax-highlighting must come last of everything that binds widgets, and
# it does: nothing below here loads another plugin.
if [[ -n "$ZSH_CACHE_DIR" ]]; then
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        plugin_script="$ZSH/custom/plugins/$plugin/$plugin.zsh"

        [[ -r "$plugin_script" ]] && source "$plugin_script"
    done

    unset plugin plugin_script
else
    source "$ZSH/oh-my-zsh.sh"
fi

# -----------------------------------------------------------------------------
# Shared user configuration
# -----------------------------------------------------------------------------

source "$DOTFILES_ZSH_DIR/init.zsh"
