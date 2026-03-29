# PATH setup - shared base paths
# Machine-specific paths go in 10-path.local.zsh
#
# Uses append_path so that wrapping shells (tmux, nix-shell, direnv)
# keep their own PATH entries in front. Among our entries, order of
# appearance determines priority (first appended = highest).

typeset -U path

# Tier 1 — Personal overrides
append_path "$HOME/.local/bin"
append_path "$HOME/.npm-global/bin"

# Tier 2 — Language toolchains
append_path "$HOME/.cargo/bin"

# Tier 3 — Package managers
if [[ -d "/opt/homebrew/bin" ]]; then
    append_path "/opt/homebrew/bin"
    append_path "/opt/homebrew/sbin"
fi
if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    append_path "/home/linuxbrew/.linuxbrew/bin"
fi

# Tier 4 — Machine-specific paths
[[ -r "${0:h}/10-path.local.zsh" ]] && source "${0:h}/10-path.local.zsh"
