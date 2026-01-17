# Dotfiles

This directory contains personal dotfiles for creating a consistent and powerful terminal environment across macOS and Linux systems.

## Directory Overview

This is a non-code project, acting as a collection of configuration files and setup scripts. Its primary purpose is to bootstrap a developer's environment by symlinking configuration files into their expected locations and setting up shell integrations.

The setup is heavily geared towards `zsh` as the primary shell, `tmux` for terminal multiplexing, and a suite of common developer tools.

## Key Features & Conventions

*   **Idempotent Installation**: The main `install.sh` script is designed to be run multiple times without causing issues. It creates backups of existing files and correctly handles symlinks.
*   **zsh-centric**: The shell environment is managed through a series of files in the `zsh/` directory, loaded in a specific order. This includes helpers, path management, environment variables, secrets (expected to be in a separate file), aliases, and tool-specific initializations.
*   **Cross-Platform Terminal Theming**: The `terminal/` directory contains a sophisticated system for synchronizing dark/light mode across the terminal, `tmux`, and even CLI tools. On macOS, it uses a native Swift application (`appearance-watcher`) to monitor system-wide appearance changes. These settings can be propagated to remote Linux machines over SSH.
*   **Tool Integrations**: The configuration includes setup for many common developer tools, such as:
    *   `git` (with many aliases)
    *   `docker` and `docker compose`
    *   `eza` (as a modern `ls` replacement)
    *   `fzf` (for fuzzy finding)
    *   `direnv` (for project-specific environments)
    *   AI CLIs (`claude`, `codex`, `gemini`)
*   **Local Overrides**: The configuration is designed to be extended with machine-specific settings. For example, `zsh/40-tools.zsh` will source a `40-tools.local.zsh` if it exists, allowing for private or machine-specific tool setups.

## Usage and Installation

The primary way to use this repository is to run the main installer script.

**Installation Command:**

```bash
./install.sh
```

**What it does:**

1.  Symlinks the `zsh/` directory to `~/.config/zsh`.
2.  Symlinks `terminal/bin/appearance` to `~/.local/bin/appearance` (requires `~/.local/bin` to be in the `PATH`).
3.  Symlinks `terminal/tmux.conf` to `~/.tmux.conf`.
4.  On macOS, it compiles and installs a Swift-based `appearance-watcher` and sets up a `launchd` agent to run it automatically.

After running the script, you may need to update your `~/.zshrc` to source the new configuration, as prompted by the script.
