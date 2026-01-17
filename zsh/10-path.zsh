# PATH setup - shared base paths
# Machine-specific paths go in 10-path.local.zsh

typeset -U path

# Python venv shortcuts (works everywhere)
prepend_path ".venv/bin"

# User-local bins (universal)
prepend_path "$HOME/.local/bin"
prepend_path "$HOME/.cargo/bin"

# Homebrew (macOS)
if [[ -d "/opt/homebrew/bin" ]]; then
    prepend_path "/opt/homebrew/bin"
    prepend_path "/opt/homebrew/sbin"
fi

# Linuxbrew (Linux)
if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    prepend_path "/home/linuxbrew/.linuxbrew/bin"
fi

# Source machine-specific paths
[[ -r "${0:h}/10-path.local.zsh" ]] && source "${0:h}/10-path.local.zsh"

# custom npm global before brew
prepend_path "$HOME/.npm-global/bin"