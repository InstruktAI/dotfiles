# Agent Context: Zsh Configuration

This directory contains a modular set of Zsh configuration files. The files are numbered to control the loading order, and they collectively define the shell environment, including PATH, environment variables, aliases, and tool integrations.

The configuration is designed to be portable across different machines, with a system for local overrides.

## Directory Overview

*   **Purpose:** To provide a consistent and customized Zsh shell experience.
*   **Structure:** Configuration is split into multiple `.zsh` files, each with a specific responsibility.
*   **Customization:** The system uses `.local.zsh` files (which are git-ignored) for machine-specific settings, allowing the base configuration to remain generic.

## Key Files

The core of the configuration is in the numbered `.zsh` files:

*   `00-helpers.zsh`: Contains helper functions used by other scripts.
*   `05-xdg-history.zsh`: Sets up XDG base directories and configures Zsh history to be stored in a standardized location.
*   `06-options.zsh`: Configures Zsh's interactive behavior, such as history options and directory navigation.
*   `10-path.zsh`: Manages the `$PATH` environment variable, adding common binary locations for different tools and platforms (Homebrew, Cargo, etc.).
*   `20-env.zsh`: Sets environment variables, such as default editors and language settings.
*   `25-secrets.zsh`: Placeholder for loading secrets (likely intended to be machine-specific).
*   `30-aliases.zsh`: Defines a large collection of aliases for frequently used commands like `git`, `docker`, `ls` (via `eza`), and navigation.
*   `40-tools.zsh`: Integrates third-party command-line tools like `fzf`, `direnv`, and `pipx` by sourcing their respective shell configurations.
*   `45-completion-aliases.zsh`: Maps completions from original commands to their corresponding aliases (e.g., `docker` completions for the `dk` alias).
*   `completions/`: This directory holds custom completion scripts for various tools.

## Usage

These configuration files are loaded through `init.zsh`, which sources the numbered `.zsh` files in order. The numbered prefix controls dependency order (for example, helpers load before aliases and tool integrations).

The installer symlinks this directory to `~/.config/zsh` and manages a small block in the user's `~/.zshrc`. That block should live after `source $ZSH/oh-my-zsh.sh` so Oh My Zsh initializes first.

Managed snippet:

```zsh
# >>> instrukt dotfiles >>>
[[ -r "$HOME/.config/zsh/init.zsh" ]] && source "$HOME/.config/zsh/init.zsh"
# <<< instrukt dotfiles <<<
```

Machine-specific customizations (like unique paths or environment variables) can be added to files like `10-path.local.zsh` or `20-env.local.zsh` within this directory. These local files are not tracked by git, ensuring that personal settings don't interfere with the core configuration shared across systems.
