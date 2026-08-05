# -----------------------------------------------------------------------------
# Shared configuration
# -----------------------------------------------------------------------------

source "$DOTFILES_ZSH_DIR/exports.zsh"
source "$DOTFILES_ZSH_DIR/aliases.zsh"
source "$DOTFILES_ZSH_DIR/functions.zsh"
source "$DOTFILES_ZSH_DIR/bindings.zsh"
source "$DOTFILES_ZSH_DIR/completion.zsh"
source "$DOTFILES_ZSH_DIR/prompt.zsh"

# -----------------------------------------------------------------------------
# Machine-specific configuration
# -----------------------------------------------------------------------------

USERCONFIG_ZSH_DIR="$HOME/.userconfig/zsh"

[[ -r "$USERCONFIG_ZSH_DIR/local.zsh" ]] && \
    source "$USERCONFIG_ZSH_DIR/local.zsh"

# Load local secrets
if [[ -d "$USERCONFIG_ZSH_DIR/secrets" ]]; then
    for secret in "$USERCONFIG_ZSH_DIR/secrets/"*.zsh; do
        [[ -r "$secret" ]] && source "$secret"
    done
fi

# Load local extensions
if [[ -d "$USERCONFIG_ZSH_DIR/extensions" ]]; then
    for config in "$USERCONFIG_ZSH_DIR/extensions/"*.zsh; do
        [[ -r "$config" ]] && source "$config"
    done
fi
