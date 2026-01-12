# Completion setup (must run before compinit / oh-my-zsh).

# Ensure Docker CLI is discoverable early (oh-my-zsh docker plugin checks this on load).
if [[ -x "/Applications/Docker.app/Contents/Resources/bin/docker" ]]; then
  export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
fi

# Custom completions directory (generated / local overrides).
if [[ -d "$HOME/.config/zsh/completions" ]]; then
  fpath=("$HOME/.config/zsh/completions" $fpath)

  # Auto-invalidate zcompdump if any completion file is newer
  local zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"*(.N[1])
  if [[ -n "$zcompdump" ]]; then
    local newest_completion="$HOME/.config/zsh/completions"/*(.om[1]N)
    if [[ -n "$newest_completion" && "$newest_completion" -nt "$zcompdump" ]]; then
      rm -f "${ZDOTDIR:-$HOME}"/.zcompdump*
    fi
  fi
fi

# Add Homebrew site-functions to fpath (for brew-installed completions)
if [[ -d "/opt/homebrew/share/zsh/site-functions" ]]; then
  fpath=("/opt/homebrew/share/zsh/site-functions" $fpath)
fi