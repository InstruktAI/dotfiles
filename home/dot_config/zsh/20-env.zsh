# Environment variables - shared base

export LANG="nl_NL.UTF-8"
export LANGUAGE="en_US:en"
export LC_MESSAGES="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"

# Default editors (an exported EDITOR/VISUAL wins)
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"

# Node/Python defaults
export NODE_ENV="${NODE_ENV:-development}"
export PIPENV_VENV_IN_PROJECT=1

# GPG TTY for signing
export GPG_TTY=$(tty)

# Truecolor: SSH forwards TERM but not COLORTERM, so apps fall back to
# 256-color on remote shells. Assert it when missing; a terminal that
# already advertises truecolor (local case) keeps its own value.
: "${COLORTERM:=truecolor}"
export COLORTERM

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
