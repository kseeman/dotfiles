# -----------------------------------------------------------------------------
# Linux aliases
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# File system
# -----------------------------------------------------------------------------

alias ls='ls --color=auto'

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------

# sys-update is defined on every OS so the same command works everywhere. An
# AUR helper is preferred because it refreshes repo and AUR packages together;
# plain pacman only covers the repos.
if command -v paru &>/dev/null; then
    alias sys-update='paru -Syu'
elif command -v yay &>/dev/null; then
    alias sys-update='yay -Syu'
else
    alias sys-update='sudo pacman -Syu'
fi
