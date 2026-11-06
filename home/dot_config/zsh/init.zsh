# Main entry point for this zsh configuration module.
#
# Usage:
#   source /path/to/this/directory/init.zsh
#
# COMPLETION ORDER:
#   1. ~/.zshrc sources completion-pre.zsh: fpath gets this configuration's
#      completions and Homebrew's.
#   2. Oh My Zsh runs compinit, once, and its plugins register their
#      completions with compdef.
#   3. This file sources the numbered files, then the compdef scripts below.
# There is no second compinit: it would discard every compdef made before it.

# Get the directory of this script
local ZSH_CONFIG_DIR=${0:h}

# Source all numbered configuration files in order. compinit has already run,
# so compdef works in them.
for config_file in "$ZSH_CONFIG_DIR"/[0-9][0-9]-*.zsh(on); do
  # Skip .local.zsh files (the decrypted secrets) — 25-secrets.zsh sources them
  if [[ "$config_file" == *".local.zsh" ]]; then
    continue
  fi
  source "$config_file"
done

# Completion scripts of tools outside this configuration (compdef
# registrations), each loaded only where the tool is present.
[[ -r "$HOME/Workspace/InstruktAI/TeleClaude/bin/telec-completion.zsh" ]] && \
    source "$HOME/Workspace/InstruktAI/TeleClaude/bin/telec-completion.zsh"
# itsUP lives in ~/srv on servers and in a workspace checkout elsewhere.
for itsup_completion in "$HOME/srv/bin/itsup-completion.sh" \
    "$HOME/Workspace/morriz/itsUP/bin/itsup-completion.sh"; do
  [[ -r "$itsup_completion" ]] && source "$itsup_completion" && break
done
unset itsup_completion

# Clean up variables
unset ZSH_CONFIG_DIR config_file