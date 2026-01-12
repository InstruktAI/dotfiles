# Environment variables - shared base
# Machine-specific env vars go in 20-env.local.zsh

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Default editors (override in .local.zsh if needed)
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"

# Node/Python defaults
export NODE_ENV="${NODE_ENV:-development}"
export PIPENV_VENV_IN_PROJECT=1

# GPG TTY for signing
export GPG_TTY=$(tty)

# Preserve real terminal info for tmux theme detection
# Only runs outside tmux when tmux server exists
if [[ "$TERM_PROGRAM" != "tmux" && -n "$TERM_PROGRAM" ]]; then
    if command -v tmux &>/dev/null && tmux info &>/dev/null; then
        if ! tmux showenv -g REAL_TERM_PROGRAM &>/dev/null; then
            tmux setenv -g REAL_TERM_PROGRAM "$TERM_PROGRAM"
            [[ -n "$ITERM_PROFILE" ]] && tmux setenv -g REAL_ITERM_PROFILE "$ITERM_PROFILE"
        fi
    fi
fi

# Source machine-specific env
[[ -r "${0:h}/20-env.local.zsh" ]] && source "${0:h}/20-env.local.zsh"
