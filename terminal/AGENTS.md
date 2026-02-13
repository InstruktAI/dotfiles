# Agent Context: Dotfiles for Terminal

This project contains scripts and configuration files for managing terminal appearance, with automatic switching between light and dark modes.

## Project Overview

The core is an appearance manager (`bin/appearance.py`) that detects the OS appearance mode and synchronizes agent CLI themes (Claude, Gemini) accordingly. TeleClaude TUI manages its own styling independently; this script only handles mode detection, agent config sync, and SIGUSR1 signaling.

It is designed with a cross-platform and remote-first mindset. A local machine (typically macOS) can detect its own appearance settings and propagate them to a remote machine (e.g., a Linux server) via SSH environment variables.

**Key Technologies:**
*   **Python:** The main logic is in `bin/appearance.py`.
*   **Swift:** A native macOS watcher (`bin/appearance-watcher.swift`) provides event-driven theme change detection.
*   **tmux:** `tmux.conf` sets standard options; the appearance script sets the `@appearance_mode` user option.
*   **launchd (macOS):** `launchd/ai.instrukt.appearance-watcher.plist` runs the watcher as a persistent background agent.

## Architecture and Key Files

1.  **`bin/appearance.py`**: The central command-line tool (symlinked to `~/.local/bin/appearance`):
    *   `get-mode`: Detects if the OS is in `dark` or `light` mode.
    *   `get-terminal-bg`: Determines the terminal's hex background color (iTerm2 plist parsing).
    *   `reload`: Syncs agent CLI themes via a data-driven `AGENTS` table, sets tmux `@appearance_mode`, and sends SIGUSR1 to TeleClaude TUI processes.
    *   `watch`: Polls for appearance changes (Linux fallback when no native watcher is available).

2.  **`tmux.conf`**: Standard tmux configuration. Does not generate or source theme files.

3.  **macOS Native Integration:**
    *   **`bin/appearance-watcher.swift`**: Subscribes to `AppleInterfaceThemeChangedNotification` and calls `appearance reload` on changes.
    *   **`launchd/ai.instrukt.appearance-watcher.plist`**: Keeps the watcher running on user login.

**Workflow:**
*   On macOS, `launchd` starts the `appearance-watcher`.
*   When the user changes the system theme, the watcher calls `appearance reload`.
*   The script detects the new mode, updates agent settings files (Claude, Gemini), sets tmux `@appearance_mode`, and sends SIGUSR1 to any running TeleClaude TUI processes.
*   On Linux, `appearance watch` polls for mode changes as a fallback.
*   When connecting via SSH, `APPEARANCE_MODE` and `TERMINAL_BG` environment variables replicate the host's theme.

## Agent Theme Sync

Agent themes are managed via a data-driven `AGENTS` table in `appearance.py`. Each entry defines:
*   `key`: Agent identifier (e.g., `"claude"`, `"gemini"`)
*   `files`: Settings file paths to update
*   `theme_path`: JSON key path to the theme value (e.g., `["theme"]` or `["ui", "theme"]`)
*   `defaults`: Default themes per mode

Per-mode theme memory is stored in `agent_state.json` so user-chosen themes survive mode toggles.

## Core Commands

*   `appearance reload`: Sync all agent themes and signal TUI refresh.
*   `appearance get-mode`: Output current mode (dark/light).
*   `appearance get-terminal-bg`: Output terminal background hex color.
*   `appearance watch`: Poll for changes (Linux fallback).

## Customization

*   `APPEARANCE_MODE`: Override mode detection (dark/light).
*   `TERMINAL_BG`: Override terminal background (#rrggbb).
*   `APPEARANCE_LATITUDE` / `APPEARANCE_LONGITUDE`: Coordinates for sunrise-sunset fallback.
