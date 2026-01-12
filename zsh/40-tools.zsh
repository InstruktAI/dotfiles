# Tool integrations - shared base
# Machine-specific tools go in 40-tools.local.zsh

# iTerm2 shell integration (macOS)
[[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

# Docker Desktop shell init
[[ -r "$HOME/.docker/init-zsh.sh" ]] && source "$HOME/.docker/init-zsh.sh"

# pipx completions (requires argcomplete)
if is_executable pipx && is_executable register-python-argcomplete; then
    eval "$(register-python-argcomplete pipx)"
fi

# direnv
if is_executable direnv; then
    eval "$(direnv hook zsh)"
fi

# fzf - try Homebrew location first, then system
if [[ -r "/opt/homebrew/opt/fzf/shell/completion.zsh" ]]; then
    source "/opt/homebrew/opt/fzf/shell/completion.zsh"
    source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"
elif [[ -r "/usr/share/fzf/completion.zsh" ]]; then
    source "/usr/share/fzf/completion.zsh"
    source "/usr/share/fzf/key-bindings.zsh"
elif [[ -r "$HOME/.fzf.zsh" ]]; then
    source "$HOME/.fzf.zsh"
fi

# Bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    [[ -r "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
    prepend_path "$BUN_INSTALL/bin"
fi

# Source machine-specific tools
[[ -r "${0:h}/40-tools.local.zsh" ]] && source "${0:h}/40-tools.local.zsh"
