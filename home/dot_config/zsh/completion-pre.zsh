# Completion setup that must exist before Oh My Zsh runs compinit, the only
# compinit in this configuration. ~/.zshrc sources this file first; init.zsh
# does not (its name has no number), so it runs exactly once.

# The Docker CLI on PATH early: the Oh My Zsh docker plugin checks for it when
# it loads.
if [[ -x "/Applications/Docker.app/Contents/Resources/bin/docker" ]]; then
  path+=("/Applications/Docker.app/Contents/Resources/bin")
fi

# Completion directories: this configuration's own, then Homebrew's.
for completion_dir in "$HOME/.config/zsh/completions" \
    "/opt/homebrew/share/zsh/site-functions" \
    "/home/linuxbrew/.linuxbrew/share/zsh/site-functions"; do
  [[ -d "$completion_dir" ]] && fpath=("$completion_dir" $fpath)
done
unset completion_dir

# A completion file newer than the compinit cache invalidates the cache, so a
# changed completion takes effect in the next shell.
() {
  local dump newest
  dump=( "${ZDOTDIR:-$HOME}"/.zcompdump*(.N[1]) )
  newest=( "$HOME/.config/zsh/completions"/*(.om[1]N) )
  if [[ -n "$dump" && -n "$newest" && "$newest" -nt "$dump" ]]; then
    rm -f "${ZDOTDIR:-$HOME}"/.zcompdump*
  fi
}
