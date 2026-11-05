# PATH setup - shared base paths
#
# This file runs first in EVERY shell (sourced from .zshenv), interactive or
# not, so it is the one place PATH precedence must be right: a command
# installed both here and by the OS's package manager (apt, etc.) must
# resolve to the same binary regardless of context.
#
# Uses prepend_path (queued, flushed once at the end) so these tiers
# consistently outrank whatever PATH the shell already inherited — the OS
# default (e.g. apt's /usr/bin) — rather than losing to it. Order of calls is
# priority order (first call = highest).
#
# direnv (see 40-tools.zsh) reasserts its own per-directory PATH entries
# dynamically on every `cd`, after this file has already run, so it always
# wins regardless of the order built here — nothing to protect against there.

typeset -U path

# Tier 1 — Personal overrides
prepend_path "$HOME/.local/bin"
prepend_path "$HOME/.npm-global/bin"

# Tier 2 — Language toolchains
prepend_path "$HOME/.cargo/bin"

# Tier 3 — Package managers
if [[ -d "/opt/homebrew/bin" ]]; then
    prepend_path "/opt/homebrew/bin"
    prepend_path "/opt/homebrew/sbin"
fi

if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    prepend_path "/home/linuxbrew/.linuxbrew/bin"
fi

flush_prepend_path
