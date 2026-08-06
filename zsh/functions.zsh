# -----------------------------------------------------------------------------
# Fastfetch
# -----------------------------------------------------------------------------

show_fastfetch() {
    # Don't run if fastfetch is unavailable
    if ! command -v fastfetch &>/dev/null; then
        return
    fi

    # Only run in interactive shells
    [[ $- != *i* ]] && return

    # Don't run in nested sessions
    [[ -n "$TMUX" ]] && return

    # Don't run inside VS Code terminal
    [[ -n "$VSCODE_INJECTION" ]] && return

    # Only run for the initial shell
    [[ "$SHLVL" -ne 1 ]] && return

    # Don't try image rendering where Kitty protocol isn't supported
    if [[ "$TERM_PROGRAM" == "vscode" ]]; then
        fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --logo none
    else
        fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
    fi
}


# -----------------------------------------------------------------------------
# Startup display
# -----------------------------------------------------------------------------

show_fastfetch
