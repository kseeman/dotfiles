# Default applications
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less

# User binaries
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Homebrew
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/sbin:$PATH"

# -----------------------------------------------------------------------------
# Node Version Manager
# -----------------------------------------------------------------------------

export NVM_DIR="$HOME/.nvm"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi

if [[ -s "$NVM_DIR/bash_completion" ]]; then
    source "$NVM_DIR/bash_completion"
fi

# Java
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"

# PostgreSQL
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# Dotnet tools
export PATH="$PATH:$HOME/.dotnet/tools"

# Local binaries
export PATH="$HOME/.local/bin:$PATH"

# Neovim
export PATH="$HOME/.local/nvim/bin:$PATH"

# History
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000

# Autosuggestions
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# zoxide
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi
