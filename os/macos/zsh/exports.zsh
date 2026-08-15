# -----------------------------------------------------------------------------
# macOS environment
# -----------------------------------------------------------------------------
#
# Loaded before zsh/exports.zsh (see zsh/init.zsh): this file owns the
# package-manager and toolchain paths that the shared config builds on.

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------

export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/sbin:$PATH"

# -----------------------------------------------------------------------------
# Node Version Manager
# -----------------------------------------------------------------------------

# Homebrew's nvm keeps its scripts in the keg and its installed Node versions
# in $NVM_DIR (set to ~/.nvm by the shared exports). The shared config sources
# whatever these point at, so only the location differs per OS.
export NVM_SH="/opt/homebrew/opt/nvm/nvm.sh"
export NVM_COMPLETION="/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# -----------------------------------------------------------------------------
# Java
# -----------------------------------------------------------------------------

# Guarded: java_home exits non-zero when no JDK 21 is installed, which would
# otherwise leave JAVA_HOME empty and put a bare "/bin" on PATH.
if [[ -x /usr/libexec/java_home ]]; then
    # Not `local` — this file is sourced at top level, not inside a function.
    _dotfiles_java_home="$(/usr/libexec/java_home -v 21 2>/dev/null)"

    if [[ -n "$_dotfiles_java_home" ]]; then
        export JAVA_HOME="$_dotfiles_java_home"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi

    unset _dotfiles_java_home
fi

# -----------------------------------------------------------------------------
# PostgreSQL
# -----------------------------------------------------------------------------

export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
