# -----------------------------------------------------------------------------
# OS-specific configuration
# -----------------------------------------------------------------------------

# Loaded *before* the shared files below. OS files own what genuinely differs
# per platform — package-manager paths, NVM_SH, JAVA_HOME, `ls` colors — and the
# shared config reads those. Shared files must never redefine something an OS
# file owns, so load order stays predictable in one direction only.

DOTFILES_OS_ZSH_DIR="$DOTFILES_DIR/os/$DOTFILES_OS/zsh"

if [[ -d "$DOTFILES_OS_ZSH_DIR" ]]; then
    for os_config in exports aliases functions; do
        [[ -r "$DOTFILES_OS_ZSH_DIR/$os_config.zsh" ]] && \
            source "$DOTFILES_OS_ZSH_DIR/$os_config.zsh"
    done

    unset os_config
fi

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

# Load local secrets and extensions. The (N) glob qualifier expands to nothing
# when a directory is empty; without it zsh raises "no matches found" on every
# shell start, since these directories are created before anything fills them.
if [[ -d "$USERCONFIG_ZSH_DIR/secrets" ]]; then
    for secret in "$USERCONFIG_ZSH_DIR/secrets/"*.zsh(N); do
        [[ -r "$secret" ]] && source "$secret"
    done
fi

if [[ -d "$USERCONFIG_ZSH_DIR/extensions" ]]; then
    for config in "$USERCONFIG_ZSH_DIR/extensions/"*.zsh(N); do
        [[ -r "$config" ]] && source "$config"
    done
fi
