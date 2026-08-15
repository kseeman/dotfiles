# -----------------------------------------------------------------------------
# macOS aliases
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# File system
# -----------------------------------------------------------------------------

# BSD ls needs -G for color; GNU ls from coreutils (installed as `gls`) is
# preferred when present since its output matches Linux.
if [[ -x /opt/homebrew/bin/gls ]]; then
    alias ls='gls --color=auto'
elif [[ -x /usr/local/bin/gls ]]; then
    alias ls='gls --color=auto'
else
    alias ls='ls -G'
fi

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------

# sys-update is defined on every OS so the same command works everywhere;
# brew-update is kept as the familiar macOS-specific name.
alias brew-update='brew update && brew upgrade && brew cleanup'
alias sys-update='brew-update'

# -----------------------------------------------------------------------------
# Finder
# -----------------------------------------------------------------------------

alias show-hidden='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
alias hide-hidden='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'
