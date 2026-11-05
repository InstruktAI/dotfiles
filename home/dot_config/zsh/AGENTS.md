# Agent Context: Zsh Configuration

This directory contains a modular set of Zsh configuration files. The files are numbered to control the loading order, and they collectively define the shell environment, including PATH, environment variables, aliases, and tool integrations.

The configuration is portable across machines; where machines differ, chezmoi templates and machine-local chezmoi data decide.

## Directory Overview

*   **Purpose:** To provide a consistent and customized Zsh shell experience.
*   **Structure:** Configuration is split into multiple `.zsh` files, each with a specific responsibility.
*   **Customization:** Machine differences come from chezmoi data (e.g. `zsh.dir_aliases` in `30-aliases.zsh.tmpl`). The only `.local.zsh` file is `25-secrets.local.zsh`, decrypted by chezmoi from its age-encrypted source.

## Key Files

The core of the configuration is in the numbered `.zsh` files:

*   `00-helpers.zsh`: Contains helper functions used by other scripts.
*   `05-xdg-history.zsh`: Sets up XDG base directories and configures Zsh history to be stored in a standardized location.
*   `06-options.zsh`: Configures Zsh's interactive behavior, such as history options and directory navigation.
*   `10-path.zsh`: Manages the `$PATH` environment variable, adding common binary locations for different tools and platforms (Homebrew, Cargo, etc.).
*   `20-env.zsh`: Sets environment variables, such as default editors and language settings.
*   `25-secrets.zsh`: Sources the decrypted `25-secrets.local.zsh`.
*   `30-aliases.zsh.tmpl`: Defines a large collection of aliases for frequently used commands like `git`, `docker`, `ls` (via `eza`), and navigation.
*   `40-tools.zsh`: Integrates third-party command-line tools (iTerm2 shell integration, Docker, `pipx`, Bun) by sourcing their shell configurations.
*   `45-completion-aliases.zsh`: Maps completions from original commands to their corresponding aliases (e.g., `docker` completions for the `dk` alias).
*   `completions/`: This directory holds custom completion scripts for various tools.

## Usage

These configuration files are loaded through `init.zsh`, which sources the numbered `.zsh` files in order. The numbered prefix controls dependency order (for example, helpers load before aliases and tool integrations).

chezmoi deploys this directory to `~/.config/zsh` (source: `home/dot_config/zsh/` in the dotfiles repository) and keeps a small block in the user's `~/.zshrc` through `home/modify_dot_zshrc`. That block lives after `source $ZSH/oh-my-zsh.sh` so Oh My Zsh initializes first.

Managed snippet:

```zsh
# >>> instrukt dotfiles >>>
[[ -r "$HOME/.config/zsh/init.zsh" ]] && source "$HOME/.config/zsh/init.zsh"
# <<< instrukt dotfiles <<<
```

Change these files in the source, never in `~/.config/zsh`: chezmoi overwrites the targets on the next apply.
