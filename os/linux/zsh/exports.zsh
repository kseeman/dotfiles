# -----------------------------------------------------------------------------
# Linux environment
# -----------------------------------------------------------------------------
#
# Loaded before zsh/exports.zsh (see zsh/init.zsh): this file owns the
# package-manager and toolchain paths that the shared config builds on.

# -----------------------------------------------------------------------------
# Node Version Manager
# -----------------------------------------------------------------------------

# Arch's nvm package installs the scripts system-wide under /usr/share/nvm
# rather than cloning into ~/.nvm the way the upstream installer does. Node
# versions still land in $NVM_DIR (~/.nvm), so the shared config is identical.
if [[ -s /usr/share/nvm/nvm.sh ]]; then
    export NVM_SH="/usr/share/nvm/nvm.sh"
    export NVM_COMPLETION="/usr/share/nvm/bash_completion"
fi

# -----------------------------------------------------------------------------
# Java
# -----------------------------------------------------------------------------

# archlinux-java keeps /usr/lib/jvm/default symlinked at the active JDK, which
# is the closest equivalent to macOS's /usr/libexec/java_home. Switch versions
# with `sudo archlinux-java set jdk21-openjdk`.
#
# Skipped when JAVA_HOME is already set, so a version manager (SDKMAN, jenv)
# that ran earlier keeps ownership of the toolchain rather than being silently
# overridden by the distro JDK.
if [[ -z "${JAVA_HOME:-}" && -d /usr/lib/jvm/default ]]; then
    export JAVA_HOME="/usr/lib/jvm/default"
    export PATH="$JAVA_HOME/bin:$PATH"
fi
