# -----------------------------------------------------------------------------
# OS detection
# -----------------------------------------------------------------------------
#
# Sourced by both install.sh (bash) and zsh/bootstrap.zsh (zsh), so this file
# must stay POSIX sh — no arrays, no [[ ]], no zsh/bash-only builtins.
#
# Everything OS-specific in this repo keys off the two values below:
#
#   DOTFILES_OS      macos | linux
#   DOTFILES_DISTRO  arch | debian | fedora | "" (empty on macOS/unknown)
#
# and lives under os/$DOTFILES_OS/.

dotfiles_detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        *) echo "unsupported" ;;
    esac
}

# Normalizes the distro to a *family*, so derivatives resolve to the family
# whose package manager they actually use (CachyOS/EndeavourOS -> arch,
# Ubuntu/Pop -> debian). Reads /etc/os-release in a subshell so its ID/NAME/
# VERSION variables don't leak into an interactive shell.
dotfiles_detect_distro() {
    if [ ! -r /etc/os-release ]; then
        echo ""
        return
    fi

    ids="$( . /etc/os-release 2>/dev/null && printf '%s %s' "${ID:-}" "${ID_LIKE:-}" )"

    case " $ids " in
        *arch*) echo "arch" ;;
        *debian* | *ubuntu*) echo "debian" ;;
        *fedora* | *rhel*) echo "fedora" ;;
        *) echo "" ;;
    esac
}
