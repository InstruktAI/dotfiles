# Gemini Context: Dotfiles for Terminal

This project contains a sophisticated set of scripts and configuration files for managing the appearance of the terminal and tmux, with a focus on automatic switching between light and dark modes.

## Project Overview

The core of this project is a theming engine that dynamically generates configurations for `tmux` and other command-line tools based on the system's appearance mode (light or dark) and the terminal's background color.

It is designed with a cross-platform and remote-first mindset. A local machine (typically macOS) can detect its own appearance settings and propagate them to a remote machine (e.g., a Linux server) via SSH environment variables.

**Key Technologies:**
*   **Python:** The main logic is in the `bin/appearance` script.
*   **Swift:** A native macOS watcher (`bin/appearance-watcher.swift`) provides an efficient, event-driven way to detect theme changes without polling.
*   **Python:** A small, embedded Python script is used to extract background color information from iTerm2's configuration on macOS.
*   **tmux:** The configuration in `tmux.conf` integrates with the scripting layer to apply the dynamic theme.
*   **launchd (macOS):** A service file (`launchd/ai.instrukt.appearance-watcher.plist`) is used to run the Swift-based watcher as a persistent background agent.

## Architecture and Key Files

The system is composed of several key components that work together:

1.  **`bin/appearance`**: The central command-line tool. This powerful Bash script has several functions:
    *   `get-mode`: Detects if the OS is in `dark` or `light` mode.
    *   `get-terminal-bg`: Determines the terminal's hex background color, with special support for iTerm2.
    *   `tmux-theme`: Generates a temporary tmux theme file (`/tmp/tmux-theme.conf`) with colors calculated based on the current mode and background.
    *   `reload`: The main action command. It re-calculates all colors, regenerates the tmux theme, and reloads the configuration for tmux and other supported tools (like the Gemini and Claude CLIs).

2.  **`tmux.conf`**: The main tmux configuration file. It sets standard tmux options and, most importantly, executes `~/.local/bin/appearance tmux-theme` and then sources the generated theme file. This makes the theming dynamic on every new tmux session.

3.  **macOS Native Integration:**
    *   **`bin/appearance-watcher.swift`**: A lightweight Swift program that subscribes to macOS's native `AppleInterfaceThemeChangedNotification`. When a user toggles light/dark mode in System Settings, it fires.
    *   **`launchd/ai.instrukt.appearance-watcher.plist`**: A service configuration file that tells macOS to run the compiled `appearance-watcher` program automatically on user login and keep it running.

**Workflow:**
*   On macOS, `launchd` starts the `appearance-watcher`.
*   When the user changes the system theme, the watcher executes `appearance reload`.
*   The `appearance` script detects the new mode and background color, regenerates the theme files, and signals `tmux` to reload its configuration.
*   When connecting to a remote machine via SSH, the user can pass `APPEARANCE_MODE` and `TERMINAL_BG` as environment variables to replicate the host's theme.

## Development and Usage

### Core Commands

The primary interface is the `appearance` script. The most common commands are:

*   `appearance reload`: Manually trigger a full reload of all themes.
*   `appearance get-mode`: Check the currently detected appearance mode.
*   `appearance get-terminal-bg`: Check the currently detected terminal background color.

### Installation and Setup

As described in the README, an `install.sh` script (not present in the listing, but documented) handles the setup:
1.  Symlinking `bin/appearance` to a directory in the user's `$PATH` (e.g., `~/.local/bin/`).
2.  Symlinking `tmux.conf` to `~/.tmux.conf`.
3.  On macOS, compiling the Swift watcher (`swiftc -o bin/appearance-watcher bin/appearance-watcher.swift`) and installing the `launchd` agent.

### Customization

The behavior can be customized using environment variables, which are particularly useful for the remote SSH use case. The most important ones are:
*   `APPEARANCE_MODE`: Force the mode to `dark` or `light`, overriding local detection.
*   `TERMINAL_BG`: Force the terminal background to a specific hex color (e.g., `#2E3440`).
