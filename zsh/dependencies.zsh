#!/usr/bin/env zsh

missing=()

check_command() {
    if ! command -v "$1" &>/dev/null; then
        missing+=("$1")
    fi
}

check_nvm() {
    if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
        missing+=("nvm")
    fi
}

echo "Checking shell dependencies..."

check_command git
check_command nvim
check_command node
check_command pnpm
check_command zoxide
check_command fastfetch
check_command bat
check_command rg

check_nvm

if (( ${#missing[@]} > 0 )); then
    echo ""
    echo "Missing dependencies:"
    
    for dep in "${missing[@]}"; do
        echo "  - $dep"
    done

    echo ""
    echo "Install missing tools before using this dotfiles setup."
    exit 1
fi

echo "All dependencies installed."
