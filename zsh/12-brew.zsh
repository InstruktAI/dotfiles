# Homebrew shell environment: HOMEBREW_PREFIX/CELLAR/REPOSITORY, MANPATH,
# INFOPATH, brew completions, and brew on PATH — via `brew shellenv`.
#
# 10-path.zsh already puts brew ahead of the OS's PATH, cheaply (no subprocess
# spawn), for every shell. This file's PATH prepend is therefore a no-op
# (typeset -U path dedups); what this actually contributes is
# MANPATH/INFOPATH/HOMEBREW_PREFIX/CELLAR/REPOSITORY and brew's completions,
# which are only worth a `brew` subprocess spawn interactively.
#
# Cross-OS and transparent: uses the first brew binary that exists (Apple
# Silicon, Intel mac, Linuxbrew) and no-ops on machines without brew. This is
# the single source for brew setup; do NOT hardcode a brew path in ~/.zshrc.
#
# Interactive-only by design: sourced via init.zsh (from .zshrc), NOT .zshenv.
# `brew shellenv` spawns the brew binary, which is too slow for every
# non-interactive `ssh host '<cmd>'`; those only need brew on PATH, which
# 10-path.zsh already provides cheaply via prepend_path.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$_brew" ]]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew
