# Tool integrations - shared base

# iTerm2 shell integration (macOS)
[[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

# Docker Desktop shell init
[[ -r "$HOME/.docker/init-zsh.sh" ]] && source "$HOME/.docker/init-zsh.sh"

# pipx completions (requires argcomplete)
if is_executable pipx && is_executable register-python-argcomplete; then
    eval "$(register-python-argcomplete pipx)"
fi

# Bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    [[ -r "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
    append_path "$BUN_INSTALL/bin"
fi
