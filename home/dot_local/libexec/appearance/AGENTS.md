# Agent Context: Appearance Management

Appearance management: dark/light detection with automatic switching. The pieces live across the chezmoi source: `home/dot_local/bin/executable_appearance` (the CLI, deployed to `~/.local/bin/appearance`), this directory (the macOS watcher, deployed to `~/.local/libexec/appearance`), `home/dot_config/appearance/config.toml.tmpl`, and the launchd/systemd templates.

## Project Overview

The core is an appearance manager (`appearance`) that detects the current dark/light mode and synchronizes agent CLI themes (Claude, Gemini/Antigravity, Codex) accordingly. TeleClaude TUI manages its own styling independently; this script only handles mode detection, agent config sync, and SIGUSR1 signaling.

Platform handling lives behind a single `Platform` seam (`MacOSPlatform` / `LinuxPlatform`), so the rest of the code is OS-agnostic. Both platforms read the same configuration: `~/.config/appearance/config.toml`, rendered by chezmoi from its data, with `APPEARANCE_*` environment variables as overrides.

**Key Technologies:**
*   **Python:** The main logic is in `appearance` (a uv script). It logs through the shared InstruktAI logger.
*   **Swift:** A native macOS watcher (`appearance-watcher.swift`, committed compiled as `executable_appearance-watcher` so every machine runs the same binary) provides event-driven theme change detection (KVO on `NSApp.effectiveAppearance`).
*   **tmux:** `~/.tmux.conf` sets standard options; the appearance script sets the `@appearance_mode` user option on it from here.
*   **launchd (macOS):** runs the Swift watcher and the solar `apply-system` job.
*   **systemd (Linux):** a `--user` service runs `appearance watch`.

## Architecture and Key Files

1.  **`appearance`**: The central command-line tool (`~/.local/bin/appearance`):
    *   `get-mode`: Resolves the current mode — `APPEARANCE_MODE` override → the platform's native signal (macOS `AppleInterfaceStyle`; Linux freedesktop `color-scheme` via the XDG portal, falling back to gsettings) → solar (sunrise/sunset) when the platform expresses no preference.
    *   `get-terminal-bg`: Determines the terminal's hex background color (macOS iTerm2 plist parsing; None elsewhere).
    *   `reload`: Syncs agent CLI themes via a data-driven `AGENTS` table, sets tmux `@appearance_mode`, and sends SIGUSR1 to TeleClaude TUI processes.
    *   `apply-system`: Drives the OS appearance from solar mode, once per genuine sunrise/sunset crossing per day (edge-triggered). Cross-platform: macOS via `osascript`, Linux via `gsettings` `color-scheme`.
    *   `watch`: Long-running poll (5-minute interval) that applies the current mode on startup, then reloads on change. This is the Linux run loop.

2.  **macOS runtime (launchd):**
    *   **`appearance-watcher.swift`**: Subscribes to the OS appearance change (macOS Auto mode switches this at sunset/sunrise) and calls `appearance reload`.
    *   **`ai.instrukt.appearance-watcher.plist`**: Keeps the watcher running.
    *   **`ai.instrukt.appearance-system.plist`**: Runs `appearance apply-system` every 5 minutes to apply the custom solar offset.

3.  **Linux runtime (systemd):**
    *   **`appearance.service`**: A `--user` service running `appearance watch` (5-minute poll), enabled by its chezmoi `run_onchange_` script.

## Installation

chezmoi deploys the CLI, the watcher, the config file and the service definitions; `run_onchange_after_50-*` scripts reload a launchd agent or restart the systemd unit whenever its definition (or, for the watcher, the binary) changes. To rebuild the watcher after editing its Swift source:

```bash
swiftc -O -o home/dot_local/libexec/appearance/executable_appearance-watcher \
    home/dot_local/libexec/appearance/appearance-watcher.swift
```

Commit the binary: every machine then runs identical bytes, so macOS keeps one Full Disk Access identity for it.

## Agent Theme Sync

Agent themes are managed via a data-driven `AGENTS` table in `appearance.py`. Each entry defines:
*   `key`: Agent identifier (e.g., `"claude"`, `"gemini"`, `"codex"`)
*   `files`: Settings file paths to update
*   `theme_path`: Nested key path to the theme value (e.g., `["theme"]` or `["tui", "theme"]`)
*   `defaults`: Default themes per mode
*   `fmt`: `"json"` or `"toml"` codec

Per-mode theme memory is stored in `$XDG_STATE_HOME/appearance/agent_state.json` so user-chosen themes survive mode toggles.

## Core Commands

*   `appearance get-mode`: Output current mode (dark/light).
*   `appearance get-terminal-bg`: Output terminal background hex color.
*   `appearance reload`: Sync all agent themes and signal TUI refresh.
*   `appearance apply-system`: Apply solar mode to the OS on a sunrise/sunset crossing.
*   `appearance watch`: Poll for changes and reload (the Linux run loop).

## Configuration

The same settings apply on both platforms. `~/.config/appearance/config.toml` is rendered by chezmoi from the machine's data; an environment variable of the same meaning overrides it:

*   `APPEARANCE_MODE`: Override mode detection (dark/light).
*   `TERMINAL_BG`: Override terminal background (#rrggbb).
*   `APPEARANCE_LATITUDE` / `APPEARANCE_LONGITUDE` (`[location]`): Explicit coordinates for the solar computation. Without them the location is the time zone's reference point from the tz database; a zone without one (e.g. `UTC`) means no solar switching, logged once.
*   `APPEARANCE_DARK_OFFSET_MINUTES` (`[dark_offset].minutes`): Start dark mode this many minutes before sunset.
*   `APPEARANCE_DST_DARK_OFFSET_MINUTES` (`[dark_offset].dst_minutes`): Extra dark offset while local DST is active.
*   `APPEARANCE_LOG_LEVEL`: Logger level (DEBUG/INFO/WARNING/ERROR; default INFO). Logs land in `$XDG_STATE_HOME/instrukt-ai/appearance/appearance.log` (default `~/.local/state/instrukt-ai/appearance/appearance.log`).
