# Main entry point for this zsh configuration module.
#
# Usage:
#   source /path/to/this/directory/init.zsh

# Get the directory of this script
local ZSH_CONFIG_DIR=${0:h}

# 1. Add this directory's completions to fpath.
if [[ -d "$ZSH_CONFIG_DIR/completions" ]]; then
  # Prepend to fpath so our completions take precedence
  fpath=("$ZSH_CONFIG_DIR/completions" $fpath)
fi

# 2. Source all numbered configuration files in order.
#    Sorted by name (numerically due to 00- prefix).
for config_file in "$ZSH_CONFIG_DIR"/[0-9][0-9]-*.zsh(on); do
  # Skip .local.zsh files as they are sourced by their parent files
  if [[ "$config_file" == *".local.zsh" ]]; then
    continue
  fi
  
  source "$config_file"
done

# 3. Re-init completions if necessary
#    Since we might be loading this after oh-my-zsh (which runs compinit),
#    and we've just modified fpath, we need to refresh completions.
if (( $+functions[compinit] )); then
  autoload -Uz compinit && compinit -C
fi

# Clean up variables
unset ZSH_CONFIG_DIR config_file