# Agent Context: Appearance Management

This directory contains scripts and configuration files for managing dark/light appearance, with automatic switching between light and dark modes.

## Project Overview

The core is an appearance manager (`bin/appearance.py`) that detects the current dark/light mode and synchronizes agent CLI themes (Claude, Gemini/Antigravity, Codex) accordingly. TeleClaude TUI manages its own styling independently; this script only handles mode detection, agent config sync, and SIGUSR1 signaling.

Platform handling lives behind a single `Platform` seam (`MacOSPlatform` / `LinuxPlatform`), so the rest of the code is OS-agnostic. Both platforms read the same `APPEARANCE_*` configuration.

**Key Technologies:**
*   **Python:** The main logic is in `bin/appearance.py`. It logs through the shared InstruktAI logger.
*   **Swift:** A native macOS watcher (`bin/appearance-watcher.swift`) provides event-driven theme change detection (KVO on `NSApp.effectiveAppearance`).
*   **tmux:** `tmux/tmux.conf` (a sibling directory) sets standard options; the appearance script sets the `@appearance_mode` user option on it from here.
*   **launchd (macOS):** runs the Swift watcher and the solar `apply-system` job.
*   **systemd (Linux):** a `--user` service runs `appearance watch`.

## Architecture and Key Files

1.  **`bin/appearance.py`**: The central command-line tool (symlinked to `~/.local/bin/appearance`):
    *   `get-mode`: Resolves the current mode — `APPEARANCE_MODE` override → the platform's native signal (macOS `AppleInterfaceStyle`; Linux freedesktop `color-scheme` via the XDG portal, falling back to gsettings) → solar (sunrise/sunset) when the platform expresses no preference.
    *   `get-terminal-bg`: Determines the terminal's hex background color (macOS iTerm2 plist parsing; None elsewhere).
    *   `reload`: Syncs agent CLI themes via a data-driven `AGENTS` table, sets tmux `@appearance_mode`, and sends SIGUSR1 to TeleClaude TUI processes.
    *   `apply-system`: Drives the OS appearance from solar mode, once per genuine sunrise/sunset crossing per day (edge-triggered). Cross-platform: macOS via `osascript`, Linux via `gsettings` `color-scheme`.
    *   `watch`: Long-running poll (5-minute interval) that applies the current mode on startup, then reloads on change. This is the Linux run loop.

2.  **macOS runtime (launchd):**
    *   **`bin/appearance-watcher.swift`**: Subscribes to the OS appearance change (macOS Auto mode switches this at sunset/sunrise) and calls `appearance reload`.
    *   **`launchd/ai.instrukt.appearance-watcher.plist`**: Keeps the watcher running.
    *   **`launchd/ai.instrukt.appearance-system.plist`**: Runs `appearance apply-system` every 5 minutes to apply the custom solar offset.

3.  **Linux runtime (systemd):**
    *   **`systemd/appearance.service`**: A `--user` service running `appearance watch` (5-minute poll), enabled by `install-runtime.sh`.

## Install / runtime split

*   **`make install`** (`setup/install-core.sh`): user tier — symlinks, shell activation, iTerm2 prefs, and provisioning of the InstruktAI log directory for the appearance app.
*   **`make install-runtime`** (`setup/install-runtime.sh`): daemon tier — renders and loads the launchd agents on macOS, or renders and enables the systemd `--user` service on Linux. Both are fed the same `APPEARANCE_*` config through one renderer.

## Agent Theme Sync

Agent themes are managed via a data-driven `AGENTS` table in `appearance.py`. Each entry defines:
*   `key`: Agent identifier (e.g., `"claude"`, `"gemini"`, `"codex"`)
*   `files`: Settings file paths to update
*   `theme_path`: Nested key path to the theme value (e.g., `["theme"]` or `["tui", "theme"]`)
*   `defaults`: Default themes per mode
*   `fmt`: `"json"` or `"toml"` codec

Per-mode theme memory is stored in `agent_state.json` so user-chosen themes survive mode toggles.

## Core Commands

*   `appearance get-mode`: Output current mode (dark/light).
*   `appearance get-terminal-bg`: Output terminal background hex color.
*   `appearance reload`: Sync all agent themes and signal TUI refresh.
*   `appearance apply-system`: Apply solar mode to the OS on a sunrise/sunset crossing.
*   `appearance watch`: Poll for changes and reload (the Linux run loop).

## Configuration

The same variables apply on both platforms and are injected into the launchd plists and the systemd unit:

*   `APPEARANCE_MODE`: Override mode detection (dark/light).
*   `TERMINAL_BG`: Override terminal background (#rrggbb).
*   `APPEARANCE_LATITUDE` / `APPEARANCE_LONGITUDE`: Coordinates for the solar computation.
*   `APPEARANCE_DARK_OFFSET_MINUTES`: Start dark mode this many minutes before sunset (default 0).
*   `APPEARANCE_DST_DARK_OFFSET_MINUTES`: Extra dark offset while local DST is active (default 0).
*   `APPEARANCE_LOG_LEVEL`: Logger level (DEBUG/INFO/WARNING/ERROR; default INFO). Logs land in `/var/log/instrukt-ai/appearance/appearance.log`.
