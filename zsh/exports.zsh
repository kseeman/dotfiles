# Shared environment. Anything platform-specific — Homebrew paths, JAVA_HOME,
# where nvm.sh lives — belongs in os/<os>/zsh/exports.zsh, which is sourced
# before this file.

# Default applications
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less

# User binaries
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# -----------------------------------------------------------------------------
# Node Version Manager
# -----------------------------------------------------------------------------

# Node versions live under $NVM_DIR on every platform; only the location of the
# nvm.sh script itself differs (Homebrew keg on macOS, /usr/share on Arch), so
# NVM_SH and NVM_COMPLETION are set by os/<os>/zsh/exports.zsh.
export NVM_DIR="$HOME/.nvm"

if [[ -n "${NVM_SH:-}" && -s "$NVM_SH" ]]; then
    source "$NVM_SH"
fi

if [[ -n "${NVM_COMPLETION:-}" && -s "$NVM_COMPLETION" ]]; then
    source "$NVM_COMPLETION"
fi

# Dotnet tools
export PATH="$PATH:$HOME/.dotnet/tools"

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
