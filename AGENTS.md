# Dotfiles

This directory contains personal dotfiles for creating a consistent and powerful terminal environment across macOS and Linux systems.

## Directory Overview

This is a non-code project, acting as a collection of configuration files and setup scripts. Its primary purpose is to bootstrap a developer's environment by symlinking configuration files into their expected locations and setting up shell integrations.

The setup is heavily geared towards `zsh` as the primary shell, `tmux` for terminal multiplexing, and a suite of common developer tools.

## Key Features & Conventions

*   **Idempotent Installation**: The main `install.sh` script is designed to be run multiple times without causing issues. It creates backups of existing files and correctly handles symlinks.
*   **zsh-centric**: The shell environment is managed through a series of files in the `zsh/` directory, loaded in a specific order. This includes helpers, path management, environment variables, secrets (expected to be in a separate file), aliases, and tool-specific initializations.
*   **Cross-Platform Appearance Theming**: The `appearance/` directory synchronizes dark/light mode across the terminal, `tmux`, and CLI tools. macOS uses a native Swift watcher (`appearance-watcher`) for event-driven changes plus a launchd solar job; Linux uses a systemd `--user` service that polls. `APPEARANCE_MODE`/`TERMINAL_BG` env overrides let a host's theme be replicated across machines.
*   **Tool Integrations**: The configuration includes setup for many common developer tools, such as:
    *   `git` (with many aliases)
    *   `docker` and `docker compose`
    *   `eza` (as a modern `ls` replacement)
    *   `fzf` (for fuzzy finding)
    *   `direnv` (for project-specific environments)
    *   AI CLIs (`claude`, `codex`, `gemini`)
*   **Local Overrides**: The configuration is designed to be extended with machine-specific settings. For example, `zsh/40-tools.zsh` will source a `40-tools.local.zsh` if it exists, allowing for private or machine-specific tool setups.

## Usage and Installation

The primary entrypoint is the `Makefile`.

**Installation Commands:**

```bash
make install          # user tier: symlinks, shell activation, log provisioning
make install-runtime  # daemon tier: launchd (macOS) or systemd --user (Linux)
```

**What `make install` does:**

1.  Symlinks the `zsh/` directory to `~/.config/zsh`.
2.  Symlinks `appearance/bin/appearance.py` to `~/.local/bin/appearance` (requires `~/.local/bin` to be in the `PATH`).
3.  Symlinks `tmux/tmux.conf` to `~/.tmux.conf`.
4.  Provisions the appearance log directory under `/var/log/instrukt-ai`.

**What `make install-runtime` does:** installs the appearance service tier — on macOS the launchd agents (the Swift watcher and the solar `apply-system` job); on Linux a systemd `--user` service running `appearance watch`.

After running the script, you may need to update your `~/.zshrc` to source the new configuration, as prompted by the script.
