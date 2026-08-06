# -----------------------------------------------------------------------------
# Fastfetch
# -----------------------------------------------------------------------------

# Directory of images to draw the fastfetch logo from. One is picked at random
# per shell start; falls back to the built-in ASCII art if it's missing/empty.
FASTFETCH_IMAGE_DIR="$HOME/Pictures/TermPhotos"

# Pick a random image from FASTFETCH_IMAGE_DIR into the global
# REPLY_FASTFETCH_IMAGE, leaving it empty if there isn't one.
#
# The result is assigned to a variable rather than echoed because `$(...)` forks
# a subshell, and each fork inherits the *same* $RANDOM seed state — so
# `img="$(random_fastfetch_image)"` would return an identical "random" pick on
# every call. Uses a glob into an array rather than `ls`/`find | head` so spaces
# and non-ASCII characters in filenames are handled correctly (several of these
# filenames contain a Unicode minus).
random_fastfetch_image() {
    REPLY_FASTFETCH_IMAGE=""

    [[ -d "$FASTFETCH_IMAGE_DIR" ]] || return

    local -a images
    # (.N) = plain files only, and expand to nothing instead of erroring when
    # nothing matches.
    images=("$FASTFETCH_IMAGE_DIR"/*.(png|jpg|jpeg|gif|webp)(.N))

    (( ${#images} )) || return

    # zsh arrays are 1-indexed; RANDOM is 0-32767.
    REPLY_FASTFETCH_IMAGE="${images[RANDOM % ${#images} + 1]}"
}

# Render fastfetch with a random image logo where supported, ASCII otherwise.
# Unconditional: this is what a manual `fastfetch` runs (see zsh/aliases.zsh).
run_fastfetch() {
    if ! command -v fastfetch &>/dev/null; then
        return
    fi

    local config="$HOME/.config/fastfetch/config.jsonc"

    # Don't try image rendering where Kitty protocol isn't supported
    if [[ "$TERM_PROGRAM" == "vscode" ]]; then
        command fastfetch --config "$config" --logo none
        return
    fi

    # Only attempt an image logo in terminals that speak the Kitty graphics
    # protocol. Elsewhere fastfetch would fall back to ASCII anyway, but this
    # skips the wasted work.
    if [[ "$TERM" == xterm-kitty || -n "$KITTY_WINDOW_ID" ]]; then
        random_fastfetch_image

        if [[ -n "$REPLY_FASTFETCH_IMAGE" ]]; then
            command fastfetch --config "$config" \
                --logo-type kitty-direct \
                --logo "$REPLY_FASTFETCH_IMAGE" \
                --logo-width 30 \
                --logo-height 15
            return
        fi
    fi

    command fastfetch --config "$config"
}

# Startup banner: run_fastfetch, but only where a banner is wanted. Kept
# separate so a manual `fastfetch` isn't silenced by these guards.
show_fastfetch() {
    # Only run in interactive shells
    [[ $- != *i* ]] && return

    # Don't run in nested sessions
    [[ -n "$TMUX" ]] && return

    # Don't run inside VS Code terminal
    [[ -n "$VSCODE_INJECTION" ]] && return

    # Only run for the initial shell
    [[ "$SHLVL" -ne 1 ]] && return

    run_fastfetch
}


# -----------------------------------------------------------------------------
# Startup display
# -----------------------------------------------------------------------------

show_fastfetch
