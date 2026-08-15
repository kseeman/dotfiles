# Shared aliases. Anything platform-specific — the `ls` color flag, package
# manager commands, Finder tweaks — belongs in os/<os>/zsh/aliases.zsh, which is
# sourced before this file. Nothing here may shadow an alias an OS file owns.

# -----------------------------------------------------------------------------
# File system
# -----------------------------------------------------------------------------

# `ls` itself is aliased per-OS; these build on whatever it resolved to.
alias ll='ls -lah'
alias la='ls -A'

alias c='clear'
alias mkdir='mkdir -p'

alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

alias cat='bat'


# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------

alias gs='git status'
alias gl='git pull'
alias gp='git push'


# -----------------------------------------------------------------------------
# Editors
# -----------------------------------------------------------------------------

alias vim='nvim'


# -----------------------------------------------------------------------------
# Development
# -----------------------------------------------------------------------------

alias flex-claude='source ~/.claude.sh'


# -----------------------------------------------------------------------------
# Terminal utilities
# -----------------------------------------------------------------------------

# Run fastfetch the same way the shell-startup banner does, so a manual
# `fastfetch` also gets a random image from ~/Pictures/TermPhotos rather than
# the built-in ASCII logo. `run_fastfetch` is defined in zsh/functions.zsh.
alias fastfetch='run_fastfetch'
