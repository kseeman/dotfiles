#!/usr/bin/env bash

set -euo pipefail

# Undoes what install.sh put in place, and nothing it cannot be sure it put
# there:
#
# - Every symlink pointing into this repo is removed, and the oldest backup
#   link_config made of what it replaced (`<name>.backup.<timestamp>`) is moved
#   back. The oldest, because that is the file from before the dotfiles.
# - ~/.claude/settings.json loses the hook registrations for this repo's hook
#   scripts, which stop existing once ~/.claude/hooks is unlinked. The rest of
#   the merged settings stay: what they were before the merge cannot be told
#   from here, and the installer's backups are left for restoring by hand.
# - The HyDE themes and wallbash templates it installed are removed.
#
# Packages, Oh My Zsh, Node versions and ~/.userconfig are left alone and only
# reported: they may have been there before, or be in use since. The tool
# directories the installer creates go only with --remove-tools.
#
# The links are found rather than listed: the places the installer links into
# are scanned for symlinks that resolve into this repo. A second copy of the
# installer's list would drift the next time a link is added there.

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
REMOVE_TOOLS=false

# For display. `${path/#$HOME/~}` does not work: the replacement undergoes tilde
# expansion, turning the `~` straight back into $HOME.
TILDE='~'

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: ./uninstall.sh [--dry-run] [--remove-tools]

  --dry-run       Print every step; change nothing.
  --remove-tools  Also delete the Neovim Python venv, netcoredbg, and tmux
                  plugins the installer downloaded.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --remove-tools)
            REMOVE_TOOLS=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

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

# Links are made through ~/.dotfiles, but accept the checkout's real path too.
points_into_repo() {
    local target

    target="$(readlink "$1")" || return 1

    [[ "$target" == "$HOME/.dotfiles/"* || "$target" == "$DOTFILES_DIR/"* ]]
}

# Timestamps sort lexically, so the first is the oldest.
oldest_backup() {
    compgen -G "$1.backup.*" | sort | head -n 1 || true
}

# Every symlink into the repo, in the places install.sh and the OS installers
# link to. ~/.config goes two deep for ~/.config/<app>/<file>; symlinked
# directories such as ~/.config/nvim are not followed, so nothing inside the
# repo is listed. ~/.dotfiles itself is handled last, separately.
repo_links() {
    {
        find "$HOME" -maxdepth 1 -type l 2>/dev/null || true
        find "$HOME/.config" -maxdepth 2 -type l 2>/dev/null || true
        find "$HOME/.local/bin" -maxdepth 1 -type l 2>/dev/null || true
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

# -----------------------------------------------------------------------------
# Start
# -----------------------------------------------------------------------------

info "Uninstalling dotfiles from:"
echo "$DOTFILES_DIR"

if [[ "$DRY_RUN" == true ]]; then
    echo "Running in dry-run mode. No changes will be made."
fi

source "$DOTFILES_DIR/lib/os.sh"
DOTFILES_OS="$(dotfiles_detect_os)"

# -----------------------------------------------------------------------------
# Links
# -----------------------------------------------------------------------------

info "Removing links into the repo..."

links="$(repo_links)"

if [[ -z "$links" ]]; then
    echo "None found."
fi

while IFS= read -r link; do
    [[ -n "$link" ]] || continue

    run "rm '$link'"

    backup="$(oldest_backup "$link")"

    if [[ "$DRY_RUN" == true ]]; then
        verb_restore="Would restore"; verb_remove="Would remove"
    else
        verb_restore="Restored"; verb_remove="Removed"
    fi

    if [[ -n "$backup" ]]; then
        run "mv '$backup' '$link'"
        echo "$verb_restore ${link/#$HOME/$TILDE} from $(basename "$backup")"
    else
        echo "$verb_remove ${link/#$HOME/$TILDE}"
    fi
done <<< "$links"

# -----------------------------------------------------------------------------
# Claude Code settings
# -----------------------------------------------------------------------------

# Hook registrations name scripts by path. With ~/.claude/hooks unlinked, a
# registration left behind makes Claude Code run a script that is not there.
# Only registrations for this repo's hook scripts go; any of the user's own stay.
settings="$HOME/.claude/settings.json"

if [[ -f "$settings" && ! -L "$settings" ]]; then
    info "Removing this repo's hooks from ~/.claude/settings.json..."

    hook_names=()
    for hook in "$DOTFILES_DIR"/claude/hooks/*.sh; do
        name="$(basename "$hook")"
        [[ "$name" == test-* ]] || hook_names+=("$name")
    done

    if ! command -v jq &>/dev/null; then
        echo "jq not found, leaving it alone. Remove the hooks for ${hook_names[*]} by hand."
    elif [[ ${#hook_names[@]} -eq 0 ]]; then
        echo "No hook scripts in the repo, nothing to remove."
    else
        pattern="/($(IFS='|'; echo "${hook_names[*]//./\\.}"))"

        filtered="$(mktemp)"

        if ! jq --arg re "$pattern" '
            if .hooks then
                .hooks |= (
                    with_entries(.value |= (
                        map(.hooks |= map(select((.command // "") | test($re) | not)))
                        | map(select((.hooks | length) > 0))
                    ))
                    | with_entries(select((.value | length) > 0))
                )
                | if (.hooks | length) == 0 then del(.hooks) else . end
            else . end
        ' "$settings" > "$filtered" 2>/dev/null; then
            rm -f "$filtered"
            echo "Could not parse it as JSON, leaving it alone."
        elif cmp -s <(jq -S . "$settings") <(jq -S . "$filtered"); then
            rm -f "$filtered"
            echo "No hooks of this repo registered."
        elif [[ "$DRY_RUN" == true ]]; then
            rm -f "$filtered"
            echo "[dry-run] remove hook registrations for ${hook_names[*]}"
        else
            backup="${settings}.backup.$(date +%Y%m%d%H%M%S)"
            cp "$settings" "$backup"
            mv "$filtered" "$settings"
            chmod 600 "$settings"
            echo "Removed. Previous version saved as $(basename "$backup")"
        fi
    fi

    echo "Its permissions are left as merged. The installer's backups are"
    echo "~/.claude/settings.json.backup.*, if you want an earlier version back."
fi

# -----------------------------------------------------------------------------
# HyDE themes and wallbash templates (Linux)
# -----------------------------------------------------------------------------

# Real directories and copied files, not links, so the scan above misses them.
# A theme directory also holds wallpaper state HyDE wrote, which goes with it.
for theme_path in "$DOTFILES_DIR"/os/linux/hyde-themes/*/; do
    [[ -d "$theme_path" ]] || continue

    name="$(basename "$theme_path")"
    dest="$HOME/.config/hyde/themes/$name"

    if [[ -d "$dest" ]]; then
        info "Removing HyDE theme '$name'..."
        run "rm -rf '$dest'"
        echo "Switch HyDE to another theme if it was the active one."
    fi
done

for template in "$DOTFILES_DIR"/os/linux/wallbash/*.dcol; do
    [[ -f "$template" ]] || continue

    dest="$HOME/.config/hyde/wallbash/always/$(basename "$template")"
    [[ -f "$dest" ]] || continue

    # Only an unmodified copy is certainly ours to delete.
    if cmp -s "$template" "$dest"; then
        info "Removing wallbash template $(basename "$template")..."
        run "rm '$dest'"
    else
        echo "Left ${dest/#$HOME/$TILDE}: it differs from the repo's copy."
    fi
done

# -----------------------------------------------------------------------------
# Downloaded tools
# -----------------------------------------------------------------------------

tool_paths=(
    "$HOME/.local/opt/nvim-python"
    "$HOME/.local/opt/netcoredbg"
    "$HOME/.config/tmux/plugins"
)

present_tools=()
for path in "${tool_paths[@]}"; do
    [[ -e "$path" ]] && present_tools+=("$path")
done

# Links into the venv, not the repo, so the scan above leaves it.
jupytext_link="$HOME/.local/bin/jupytext"
if [[ -L "$jupytext_link" && "$(readlink "$jupytext_link")" == "$HOME/.local/opt/nvim-python/"* ]]; then
    present_tools+=("$jupytext_link")
fi

if [[ ${#present_tools[@]} -gt 0 ]]; then
    if [[ "$REMOVE_TOOLS" == true ]]; then
        info "Removing downloaded tools..."
        for path in "${present_tools[@]}"; do
            run "rm -rf '$path'"
        done
    else
        info "Leaving downloaded tools (remove with --remove-tools):"
        for path in "${present_tools[@]}"; do
            echo "  ${path/#$HOME/$TILDE}"
        done
    fi
fi

# -----------------------------------------------------------------------------
# ~/.dotfiles
# -----------------------------------------------------------------------------

# Last, since every other link resolved through it.
if [[ -L "$HOME/.dotfiles" && "$(readlink "$HOME/.dotfiles")" == "$DOTFILES_DIR" ]]; then
    info "Removing ~/.dotfiles..."
    run "rm '$HOME/.dotfiles'"
fi

# -----------------------------------------------------------------------------
# Left in place
# -----------------------------------------------------------------------------

echo ""
echo "======================================"
if [[ "$DRY_RUN" == true ]]; then
    echo " Dry run complete: nothing was changed"
else
    echo " Dotfiles uninstalled"
fi
echo "======================================"
echo ""
echo "Left in place, since they may predate the dotfiles or be in use:"

case "$DOTFILES_OS" in
    macos)
        echo "  Homebrew packages   brew bundle list --file '$DOTFILES_DIR/os/macos/Brewfile'"
        ;;
    linux)
        echo "  Packages            $DOTFILES_DIR/os/linux/pacman.txt and aur.txt"
        ;;
esac

echo "  Oh My Zsh           run uninstall_oh_my_zsh to remove it"
echo "  Node versions       ~/.nvm"
echo "  Your own config     ~/.userconfig"
echo ""
echo "This checkout itself is untouched. Open a new terminal to pick up the"
echo "restored shell configuration."
