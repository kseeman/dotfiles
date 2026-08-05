# -----------------------------------------------------------------------------
# Local terminal functions
# -----------------------------------------------------------------------------

if [[ -f "$HOME/.local/bin/terminal-functions.sh" ]]; then
    source "$HOME/.local/bin/terminal-functions.sh"
fi


# -----------------------------------------------------------------------------
# Startup display
# -----------------------------------------------------------------------------

if command -v smart_fastfetch &>/dev/null \
    && [[ $- == *i* ]] \
    && [[ -z "$TMUX" ]] \
    && [[ -z "$VSCODE_INJECTION" ]] \
    && [[ "$SHLVL" -eq 1 ]]; then

    smart_fastfetch
fi
