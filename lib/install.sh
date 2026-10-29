# shellcheck shell=bash

# -----------------------------------------------------------------------------
# Installer helpers
# -----------------------------------------------------------------------------
#
# Sourced by install.sh, uninstall.sh and the OS installers, and by any repo
# installed on top of this one -- the desktop sources ~/.dotfiles/lib/install.sh
# rather than keeping a copy, so linking, backups and package installs behave
# the same everywhere. That makes these function names an interface: renaming
# one breaks an installer this repo cannot see.
#
# Bash, unlike lib/os.sh, which zsh also sources.
#
# Callers set, before calling:
#   DRY_RUN     true to print commands instead of running them
#   REPO_ROOTS  array of paths a link may point into and still count as this
#               install's own -- replaced without a backup by link_config, and
#               found by repo_links
#   XDG_CONFIG, XDG_BIN   for repo_links

info() {
    echo ""
    echo "==> $1"
}

run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] $*"
    else
        eval "$@"
    fi
}

# -----------------------------------------------------------------------------
# Links
# -----------------------------------------------------------------------------

# Whether a symlink resolves into one of REPO_ROOTS. Links are made through
# ~/.dotfiles, so callers list that as well as the checkout's real path.
points_into_repo() {
    local target root

    target="$(readlink "$1")" || return 1

    for root in "${REPO_ROOTS[@]}"; do
        [[ "$target" == "$root/"* ]] && return 0
    done

    return 1
}

link_config() {
    local source="$1"
    local target="$2"

    if [[ ! -e "$source" ]]; then
        echo "Missing source: $source"
        return
    fi

    # Anything already at the target is moved aside unless it is this link
    # already, including someone's own symlink (e.g. ~/.zshrc into another
    # dotfiles repo), which `ln -sfn` would otherwise replace without a trace.
    # `-L` as well as `-e`, so a dangling symlink counts as something there.
    local ours=false
    if [[ -L "$target" ]]; then
        if [[ "$(readlink "$target")" == "$source" ]] || points_into_repo "$target"; then
            ours=true
        fi
    fi

    if [[ "$ours" == false ]] && [[ -e "$target" || -L "$target" ]]; then
        # <name>.pre-dotfiles is only ever the original, from before the first
        # install -- what uninstall.sh puts back. Something appearing there
        # after that (an app replacing the link with a file) gets a timestamped
        # backup instead, so the original is never overwritten.
        local backup="${target}.pre-dotfiles"
        if [[ -e "$backup" || -L "$backup" ]]; then
            backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
        fi

        info "Backing up existing $(basename "$target") to $(basename "$backup")"
        run "mv '$target' '$backup'"
    fi

    run "ln -sfn '$source' '$target'"
}

# What to put back at a path: its .pre-dotfiles original, or failing that the
# newest timestamped backup (timestamps sort lexically). Other backups stay.
backup_for() {
    if [[ -e "$1.pre-dotfiles" || -L "$1.pre-dotfiles" ]]; then
        printf '%s' "$1.pre-dotfiles"
        return
    fi

    compgen -G "$1.backup.*" | sort | tail -n 1 || true
}

# Every symlink into REPO_ROOTS, in the places the installers link to.
# ~/.config goes two deep for ~/.config/<app>/<file>; symlinked directories
# such as ~/.config/nvim are not followed, so nothing inside the repo is
# listed. ~/.dotfiles itself is never listed: it is removed last, separately.
#
# Found rather than listed: a second copy of the installers' link list would
# drift the next time a link is added.
repo_links() {
    {
        find "$HOME" -maxdepth 1 -type l 2>/dev/null || true
        find "$XDG_CONFIG" -maxdepth 2 -type l 2>/dev/null || true
        find "$XDG_BIN" -maxdepth 1 -type l 2>/dev/null || true
        find "$HOME/.claude" -maxdepth 1 -type l 2>/dev/null || true
    } | sort -u | while IFS= read -r link; do
        [[ "$link" == "$HOME/.dotfiles" ]] && continue

        # An `if`, not `&&`: a failed test as the loop's last command would
        # become the function's status, and set -e would stop the script
        # whenever the last link scanned is not ours.
        if points_into_repo "$link"; then
            printf '%s\n' "$link"
        fi
    done
}

# Removes each link in a newline-separated list, as repo_links prints it, and
# puts back what link_config moved aside for it.
remove_repo_links() {
    local link backup verb_restore verb_remove

    # For display. `${path/#$HOME/~}` does not work: the replacement undergoes
    # tilde expansion, turning the `~` straight back into $HOME.
    local tilde='~'

    if [[ "$DRY_RUN" == true ]]; then
        verb_restore="Would restore"; verb_remove="Would remove"
    else
        verb_restore="Restored"; verb_remove="Removed"
    fi

    while IFS= read -r link; do
        [[ -n "$link" ]] || continue

        run "rm '$link'"

        backup="$(backup_for "$link")"

        if [[ -n "$backup" ]]; then
            run "mv '$backup' '$link'"
            echo "$verb_restore ${link/#$HOME/$tilde} from $(basename "$backup")"
        else
            echo "$verb_remove ${link/#$HOME/$tilde}"
        fi
    done <<< "$1"
}

# -----------------------------------------------------------------------------
# Package manifests (Arch)
# -----------------------------------------------------------------------------

# Manifests are one package per line with # comments and blank lines allowed;
# this flattens them to a space-separated list.
read_manifest() {
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1" | tr '\n' ' '
}

install_pacman_manifest() {
    local manifest="$1"
    local packages

    if [[ ! -f "$manifest" ]]; then
        echo "No $(basename "$manifest") found, skipping repository packages."
        return
    fi

    packages="$(read_manifest "$manifest")"

    if [[ -n "${packages// /}" ]]; then
        info "Installing pacman packages..."

        # --needed skips anything already present, so this is safe to re-run.
        # Left interactive on purpose: pacman shows what it's about to do.
        run "sudo pacman -S --needed $packages"
    fi
}

install_aur_manifest() {
    local manifest="$1"
    local packages aur_helper

    [[ -f "$manifest" ]] || return 0

    packages="$(read_manifest "$manifest")"

    [[ -n "${packages// /}" ]] || return 0

    if command -v paru &>/dev/null; then
        aur_helper="paru"
    elif command -v yay &>/dev/null; then
        aur_helper="yay"
    else
        echo "No AUR helper (paru/yay) found, skipping: $packages"
        return
    fi

    info "Installing AUR packages with $aur_helper..."

    run "$aur_helper -S --needed $packages"
}
