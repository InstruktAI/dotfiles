# XDG base dirs (best-effort) + history location.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" 2>/dev/null || true
mkdir -p "$XDG_STATE_HOME/zsh" "$XDG_CACHE_HOME/zsh" 2>/dev/null || true

export HISTFILE="${HISTFILE:-$XDG_STATE_HOME/zsh/history}"
export HISTSIZE="${HISTSIZE:-4096}"
export SAVEHIST="${SAVEHIST:-4096}"

# Let oh-my-zsh keep its cache out of $HOME.
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$XDG_CACHE_HOME/oh-my-zsh}"

