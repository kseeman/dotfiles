#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
INSTALL_CLAUDE=true

# Set by the OS-specific installer sourced below.
NVM_SH=""

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --no-claude)
            INSTALL_CLAUDE=false
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

link_config() {
    local source="$1"
    local target="$2"

    if [[ ! -e "$source" ]]; then
        echo "Missing source: $source"
        return
    fi

    if [[ -e "$target" && ! -L "$target" ]]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"

        info "Backing up existing $(basename "$target")"
        run "mv '$target' '$backup'"
    fi

    run "ln -sfn '$source' '$target'"
}

# settings.json is the one file in the Claude harness that Claude Code writes to
# itself — plugin enablement, auto-mode classifier state, absolute marketplace
# paths. Symlinking it would feed that machine-local state straight into this
# public repo, with no prompt. So it is merged rather than linked: the repo's
# keys win, and any key only the local install knows about survives.
#
# The tradeoff: edit the repo copy and re-run this installer. Changes made
# through /config land locally and are overwritten on the next run.
merge_json_config() {
    local source="$1"
    local target="$2"

    if [[ ! -f "$source" ]]; then
        echo "Missing source: $source"
        return
    fi

    if [[ ! -f "$target" ]]; then
        run "cp '$source' '$target'"
        return
    fi

    if ! command -v jq &>/dev/null; then
        echo "jq not found, leaving $(basename "$target") alone."
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] merge $source into $target"
        return
    fi

    # A leftover symlink would make the merge below write into the repo, which
    # is the exact thing this function exists to prevent.
    if [[ -L "$target" ]]; then
        echo "Replacing symlinked $(basename "$target") with a real file."

        rm "$target"
        cp "$source" "$target"

        return
    fi

    local merged
    merged="$(mktemp)"

    # Local first, repo second, so repo values win and local-only keys survive.
    if ! jq -s '.[0] * .[1]' "$target" "$source" > "$merged" 2>/dev/null; then
        rm -f "$merged"

        echo "Could not parse $target as JSON, leaving it alone."

        return
    fi

    if cmp -s "$merged" "$target"; then
        rm -f "$merged"

        echo "Already up to date."

        return
    fi

    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"

    cp "$target" "$backup"
    mv "$merged" "$target"

    echo "Merged. Previous version saved as $(basename "$backup")"
}

# -----------------------------------------------------------------------------
# Validate environment
# -----------------------------------------------------------------------------

info "Installing dotfiles from:"
echo "$DOTFILES_DIR"

if [[ "$DRY_RUN" == true ]]; then
    echo "Running in dry-run mode. No changes will be made."
fi

source "$DOTFILES_DIR/lib/os.sh"

DOTFILES_OS="$(dotfiles_detect_os)"
DOTFILES_DISTRO="$(dotfiles_detect_distro)"

OS_DIR="$DOTFILES_DIR/os/$DOTFILES_OS"

if [[ ! -d "$OS_DIR" ]]; then
    echo "Unsupported operating system: $(uname -s)"
    echo "Add an os/<name> directory to support it."
    exit 1
fi

echo "Detected: $DOTFILES_OS${DOTFILES_DISTRO:+ ($DOTFILES_DISTRO)}"

# -----------------------------------------------------------------------------
# OS-specific setup
# -----------------------------------------------------------------------------

# Sourced rather than executed so it inherits DRY_RUN and the helpers above,
# and can hand NVM_SH plus an optional os_link_configs() hook back to the
# shared steps below.
info "Running $DOTFILES_OS setup..."

source "$OS_DIR/install.sh"

# -----------------------------------------------------------------------------
# Dependency check
# -----------------------------------------------------------------------------

if [[ -x "$DOTFILES_DIR/zsh/dependencies.zsh" ]]; then
    info "Checking dependencies..."

    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] $DOTFILES_DIR/zsh/dependencies.zsh"
    else
        "$DOTFILES_DIR/zsh/dependencies.zsh"
    fi
fi

# -----------------------------------------------------------------------------
# NVM
# -----------------------------------------------------------------------------

info "Configuring NVM..."

# Node versions live here on every OS; only the location of nvm.sh differs,
# which is why the OS installer sets NVM_SH.
run "mkdir -p '$HOME/.nvm'"

if [[ -z "$NVM_SH" ]]; then
    echo "No NVM_SH set by the $DOTFILES_OS installer, skipping Node setup."
elif [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] source $NVM_SH"
    echo "[dry-run] nvm install --lts"
    echo "[dry-run] nvm alias default lts/*"
elif [[ ! -s "$NVM_SH" ]]; then
    echo "nvm.sh not found at $NVM_SH, skipping Node setup."
else
    export NVM_DIR="$HOME/.nvm"

    source "$NVM_SH"

    if ! nvm ls --lts &>/dev/null; then
        echo "Installing Node LTS..."

        nvm install --lts
        nvm alias default 'lts/*'
    else
        echo "Node LTS already installed."
    fi
fi

# -----------------------------------------------------------------------------
# Oh My Zsh
# -----------------------------------------------------------------------------

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."

    run 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
else
    info "Oh My Zsh already installed."
fi

# -----------------------------------------------------------------------------
# Oh My Zsh plugins
# -----------------------------------------------------------------------------

info "Installing Oh My Zsh plugins..."

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

install_omz_plugin() {
    local name="$1"
    local repo="$2"

    if [[ ! -d "$ZSH_CUSTOM/plugins/$name" ]]; then
        run "git clone '$repo' '$ZSH_CUSTOM/plugins/$name'"
    else
        echo "Plugin already installed: $name"
    fi
}

install_omz_plugin \
    "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions"

install_omz_plugin \
    "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting"

# -----------------------------------------------------------------------------
# Dotfiles symlink
# -----------------------------------------------------------------------------

info "Creating ~/.dotfiles symlink..."

run "ln -sfn '$DOTFILES_DIR' '$HOME/.dotfiles'"

# -----------------------------------------------------------------------------
# Zsh configuration
# -----------------------------------------------------------------------------

info "Linking ~/.zshrc..."

link_config \
    "$HOME/.dotfiles/zsh/zshrc" \
    "$HOME/.zshrc"

# -----------------------------------------------------------------------------
# Neovim configuration
# -----------------------------------------------------------------------------

# Shared: nvim/ is already cross-platform via profile-manager.lua, so the whole
# directory is linked on every OS.
info "Linking ~/.config/nvim..."

run "mkdir -p '$HOME/.config'"

link_config \
    "$HOME/.dotfiles/nvim" \
    "$HOME/.config/nvim"

# -----------------------------------------------------------------------------
# Neovim Python host
# -----------------------------------------------------------------------------

# A dedicated venv for Neovim's Python provider, which the python profile's
# molten-nvim (Jupyter kernels) runs inside. profiles/python/plugins.lua points
# python3_host_prog here.
#
# A venv rather than `pip install --user` because Arch's Python is marked
# externally managed (PEP 668) and refuses user installs outright, and because
# pointing the host at a project venv would break molten in every project that
# lacks pynvim.
#
# ipykernel ships a `python3` kernelspec inside the venv, which jupyter_client
# finds through sys.prefix, so :MoltenInit works before any project kernel has
# been registered.
#
# `pip install --upgrade` on every run is cheap once everything is current,
# and keeps the host in step with molten's requirements.
NVIM_PYTHON_DIR="$HOME/.local/opt/nvim-python"
NVIM_PYTHON_PACKAGES=(
    pynvim
    jupyter_client
    ipykernel
    jupytext
    nbformat
    pillow
    pyperclip
)

if command -v python3 &>/dev/null; then
    info "Configuring Neovim Python host..."

    # Also true when a Homebrew Python minor-version bump has left bin/python
    # a dangling symlink, which is why the rebuild uses --clear.
    if [[ ! -x "$NVIM_PYTHON_DIR/bin/python" ]]; then
        run "mkdir -p '$HOME/.local/opt'"
        run "python3 -m venv --clear '$NVIM_PYTHON_DIR'"
    fi

    run "'$NVIM_PYTHON_DIR/bin/python' -m pip install --quiet --upgrade pip ${NVIM_PYTHON_PACKAGES[*]}"

    # molten writes each kernel's connection file to <jupyter data dir>/runtime
    # by building that path itself, without creating the directory. On a
    # machine where Jupyter has never run, every :MoltenInit then fails with
    # ENOENT. The data dir differs per OS (~/Library/Jupyter on macOS), so ask
    # jupyter_core for it, exactly as molten does.
    run "'$NVIM_PYTHON_DIR/bin/python' -c 'import os; from jupyter_core.paths import jupyter_data_dir; os.makedirs(os.path.join(jupyter_data_dir(), \"runtime\"), exist_ok=True)'"

    # jupytext.nvim shells out to `jupytext` on PATH, and has no setting for
    # its location. Only that one binary is linked: putting the venv's bin/ on
    # PATH would shadow the project's own `python`.
    run "mkdir -p '$HOME/.local/bin'"

    link_config \
        "$NVIM_PYTHON_DIR/bin/jupytext" \
        "$HOME/.local/bin/jupytext"
else
    info "python3 not found, skipping Neovim Python host."
fi

# -----------------------------------------------------------------------------
# Claude Code configuration
# -----------------------------------------------------------------------------

# ~/.claude is a live state directory — sessions, history, credentials, and the
# per-project memory Claude writes under projects/ — so it is never linked as a
# whole. Only the curated, generic harness below is linked, which keeps
# everything Claude generates outside this repository. This repo is public;
# claude/README.md explains the boundary and what must never cross it.
#
# --no-claude skips all of it, for someone who wants the editor and shell setup
# but not these instructions, agents, skills and hooks in their own Claude Code.
# Nothing else in the install depends on it.
if [[ "$INSTALL_CLAUDE" == true ]]; then
    info "Linking Claude Code configuration..."

    run "mkdir -p '$HOME/.claude'"

    link_config \
        "$HOME/.dotfiles/claude/CLAUDE.md" \
        "$HOME/.claude/CLAUDE.md"

    link_config \
        "$HOME/.dotfiles/claude/agents" \
        "$HOME/.claude/agents"

    link_config \
        "$HOME/.dotfiles/claude/skills" \
        "$HOME/.claude/skills"

    link_config \
        "$HOME/.dotfiles/claude/hooks" \
        "$HOME/.claude/hooks"

    # Merged, not linked — see merge_json_config. Read from the repo path rather
    # than ~/.dotfiles so a dry run works before that symlink exists.
    merge_json_config \
        "$DOTFILES_DIR/claude/settings.json" \
        "$HOME/.claude/settings.json"
else
    info "Skipping Claude Code configuration (--no-claude)."
fi

# -----------------------------------------------------------------------------
# tmux configuration
# -----------------------------------------------------------------------------

# The config itself is shared; only clipboard integration differs per platform.
# The OS fragment is linked to os.conf, which tmux.conf sources at its end.
#
# The -f test reads the repo path rather than ~/.dotfiles so it still evaluates
# correctly during a dry run, when that symlink may not exist yet.
info "Linking tmux configuration..."

run "mkdir -p '$HOME/.config/tmux'"

link_config \
    "$HOME/.dotfiles/tmux/tmux.conf" \
    "$HOME/.config/tmux/tmux.conf"

if [[ -f "$OS_DIR/tmux.conf" ]]; then
    link_config \
        "$HOME/.dotfiles/os/$DOTFILES_OS/tmux.conf" \
        "$HOME/.config/tmux/os.conf"
fi

# The sessionizer is bound to prefix + f, and put on PATH so it also works from
# a plain shell. ~/.local/bin is already exported in zsh/exports.zsh.
run "mkdir -p '$HOME/.local/bin'"

link_config \
    "$HOME/.dotfiles/tmux/scripts/tmux-sessionizer" \
    "$HOME/.local/bin/tmux-sessionizer"

# -----------------------------------------------------------------------------
# tmux plugins
# -----------------------------------------------------------------------------

# tpm manages tmux-resurrect and tmux-continuum, declared at the end of
# tmux.conf. Plugins live under ~/.config/tmux/plugins, which is a real
# directory outside this repo, so nothing needs gitignoring.
#
# Cloning only bootstraps tpm itself; press prefix + I inside tmux to install
# the plugins it manages.
TPM_DIR="$HOME/.config/tmux/plugins/tpm"

if [[ ! -d "$TPM_DIR" ]]; then
    info "Installing tmux plugin manager..."

    run "git clone --depth 1 https://github.com/tmux-plugins/tpm '$TPM_DIR'"
else
    info "tmux plugin manager already installed."
fi

# -----------------------------------------------------------------------------
# OS-specific configuration links
# -----------------------------------------------------------------------------

# Which desktop configs get linked is itself platform-specific: on macOS this
# repo owns Kitty and Fastfetch, while on a Linux desktop those directories may
# already belong to the desktop environment. Each OS installer decides, and runs
# here — after the ~/.dotfiles symlink the link targets depend on.
if declare -F os_link_configs >/dev/null; then
    os_link_configs
fi

# -----------------------------------------------------------------------------
# User configuration reminder
# -----------------------------------------------------------------------------

info "Checking ~/.userconfig..."

if [[ ! -d "$HOME/.userconfig" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] create ~/.userconfig structure"
    else
        mkdir -p "$HOME/.userconfig/zsh/extensions"
        mkdir -p "$HOME/.userconfig/zsh/secrets"

        cat > "$HOME/.userconfig/README.md" <<EOF
# Local User Configuration

This directory is intentionally not managed by dotfiles.

Use:

~/.userconfig/zsh/local.zsh
    Machine-specific configuration

~/.userconfig/zsh/extensions/
    Work/project shell extensions

~/.userconfig/zsh/secrets/
    Private environment variables and credentials

~/.userconfig/nvim/local.lua
    Machine-specific Neovim code: commands, keymaps, autocmds

~/.userconfig/nvim/projects/<repo-dir-name>.lua
    Per-project Neovim settings (a returned table), e.g. maven_test_args

Do not commit this directory.
EOF

        echo ""
        echo "Created ~/.userconfig structure."
        echo "Add private or machine-specific configuration there."
    fi
else
    echo "~/.userconfig already exists."
fi

# Outside the first-run block on purpose: machines whose ~/.userconfig predates
# the nvim files get the directory too. mkdir -p is a no-op when it exists and
# never touches the files inside.
run "mkdir -p '$HOME/.userconfig/nvim/projects'"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

echo ""
echo "======================================"
echo " Dotfiles installation complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal"
echo "  2. Open Kitty for the full terminal experience"
echo "  3. Add machine-specific settings to ~/.userconfig"
echo ""
