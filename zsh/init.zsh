# Main entry point for this zsh configuration module.
#
# Usage:
#   source /path/to/this/directory/init.zsh
#
# COMPLETION SYSTEM ARCHITECTURE:
# ===============================
# Zsh has two ways to register completions:
#
# 1. Static (fpath): Put _command files in fpath directories. These are
#    autoloaded by compinit and persist across sessions via .zcompdump cache.
#    Use for: stable, rarely-changing completions.
#
# 2. Dynamic (compdef): Call `compdef _func command` at runtime. These
#    registrations are NOT cached and must run after compinit.
#    Use for: completions that call external tools or change frequently.
#
# CRITICAL ORDERING:
#   1. Modify fpath (add completion directories)
#   2. Run compinit (loads fpath completions, rebuilds cache)
#   3. Source scripts that use compdef (dynamic registrations)
#
# If you call compdef BEFORE compinit, the registration is lost when compinit
# runs (especially with -C flag which uses cached state).

# Get the directory of this script
local ZSH_CONFIG_DIR=${0:h}

# 1. Add this directory's completions to fpath.
#    These _command files will be loaded by compinit below.
if [[ -d "$ZSH_CONFIG_DIR/completions" ]]; then
  fpath=("$ZSH_CONFIG_DIR/completions" $fpath)
fi

# 2. Source all numbered configuration files in order.
#    NOTE: Do NOT put compdef calls in these files - they run before compinit!
for config_file in "$ZSH_CONFIG_DIR"/[0-9][0-9]-*.zsh(on); do
  # Skip .local.zsh files as they are sourced by their parent files
  if [[ "$config_file" == *".local.zsh" ]]; then
    continue
  fi
  source "$config_file"
done

# 3. Re-init completions.
#    -C uses cache for speed; fpath changes still take effect on next compinit.
if (( $+functions[compinit] )); then
  autoload -Uz compinit && compinit -C
fi

# 4. Source machine-specific post-compinit scripts (compdef registrations, etc.)
[[ -r "${0:h}/init.local.zsh" ]] && source "${0:h}/init.local.zsh"

# Clean up variables
unset ZSH_CONFIG_DIR config_file