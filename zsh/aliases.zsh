# -----------------------------------------------------------------------------
# File system
# -----------------------------------------------------------------------------

# Colored ls
if [[ -x /usr/local/bin/gls ]]; then
    alias ls='gls --color=auto'
elif [[ "$OSTYPE" == darwin* ]]; then
    alias ls='ls -G'
fi

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
# macOS
# -----------------------------------------------------------------------------

alias brew-update='brew update && brew upgrade && brew cleanup'

alias show-hidden='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
alias hide-hidden='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'


# -----------------------------------------------------------------------------
# Development
# -----------------------------------------------------------------------------

alias flex-claude='source ~/.claude.sh'


# -----------------------------------------------------------------------------
# Terminal utilities
# -----------------------------------------------------------------------------

alias fastfetch='fastfetch --logo-type kitty'
