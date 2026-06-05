# Terminal Appearance Setup

Cross-platform terminal/tmux appearance management with automatic dark/light mode switching.

## Features

- **Automatic mode detection**: macOS system preferences or sunrise/sunset API
- **Terminal background detection**: Reads iTerm2 configuration on macOS
- **Environment passthrough**: Host passes settings to remote sessions via SSH
- **tmux theming**: Dynamic borders, status bar, and pane styling
- **CLI theme sync**: Updates Claude, Antigravity CLI, and Codex themes

## Installation

```bash
./install.sh
```

This will:
1. Symlink `bin/appearance` to `~/.local/bin/`
2. Symlink `tmux.conf` to `~/.tmux.conf`
3. On macOS: compile Swift watcher and install launchd job

## How It Works

### Mode Detection Priority

1. `APPEARANCE_MODE` environment variable (from SSH host)
2. macOS: `defaults read -g AppleInterfaceStyle`
3. Linux: Sunrise/sunset API based on location

### Terminal Background Priority

1. `TERMINAL_BG` environment variable (from SSH host)
2. macOS: Read from iTerm2 plist configuration
3. Linux: Must be provided via environment (no local terminal)

### SSH Integration

When SSHing from macOS to a remote machine, pass appearance settings:

```bash
APPEARANCE_MODE=$(appearance get-mode) \
TERMINAL_BG=$(appearance get-terminal-bg) \
ssh user@remote
```

TeleClaude does this automatically in `pane_manager.py`.

### Agent CLI Theme Sync

`appearance reload` is imperative and idempotent. The current appearance mode is
the input, the agent table in `bin/appearance.py` defines the intended config
value for that mode, and each run writes that intended value. Re-running reload
for the same mode must converge to the same files even if a previous run, a
sync conflict, or a manual edit left stale state behind.

Per-agent preference memory may exist, but it is not authoritative. State may
only remember a user preference when the current agent config differs from the
last value that `appearance reload` applied. That proves the user or the agent
changed the theme outside the sync path. On the next reload, the script records
that external change as the preference for the mode that was active when the
last value was applied, then writes the intended value for the newly detected
mode.

The state record must therefore track both preference and provenance:

```json
{
  "agent": {
    "dark": "dark-preference",
    "light": "light-preference",
    "last_mode": "dark",
    "last_applied": "dark-preference"
  }
}
```

The synced settings locations are declared in the `AGENTS` table in
`bin/appearance.py`:

| Agent | Settings file | Theme field |
|-------|---------------|-------------|
| Claude | `~/.claude/settings.json` | `theme` |
| Claude | `~/.claude.json` | `theme` |
| Antigravity CLI | `~/.gemini/antigravity-cli/settings.json` | `colorScheme` |
| Codex | `~/.codex/config.toml` | `[tui].theme` |

Preference memory and last-applied provenance live in
`terminal/agent_state.json`.

This contract applies to every synced agent. For each agent, mode-only fields
that accept only `dark` or `light` write the current mode directly and do not
learn arbitrary preferences. Agents with real named themes may use preference
memory, provided their `last_applied` check prevents stale state from overriding
the imperative mode-to-theme mapping.

## Commands

```bash
appearance get-mode         # Output: dark or light
appearance get-terminal-bg  # Output: #rrggbb
appearance reload           # Reload all themes
appearance tmux-theme       # Generate /tmp/tmux-theme.conf
appearance focus-pane PID   # Handle tmux pane focus
appearance watch            # Poll for changes (Linux)
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APPEARANCE_MODE` | (detected) | Override mode: `dark` or `light` |
| `TERMINAL_BG` | (detected) | Override terminal background: `#rrggbb` |
| `APPEARANCE_LATITUDE` | 52.37 | Latitude for sunrise/sunset |
| `APPEARANCE_LONGITUDE` | 4.89 | Longitude for sunrise/sunset |
| `APPEARANCE_BORDER_PERCENT` | 15 | Border blend percentage |
| `APPEARANCE_STATUS_BG_PERCENT` | 10 | Status bar background blend |
| `APPEARANCE_STATUS_FG_PERCENT` | 40 | Status bar foreground blend |
| `APPEARANCE_FOCUS_DIM_PERCENT` | 10 | Inactive pane dim percentage |

## Files

```
terminal/
├── bin/
│   ├── appearance              # Main script (python)
│   └── appearance-watcher.swift # macOS watcher (Swift)
├── launchd/
│   └── ai.instrukt.appearance-watcher.plist
├── agent_state.json            # Preference memory and last-applied provenance
├── tmux.conf                   # Shared tmux configuration
├── install.sh                  # Idempotent installer
└── README.md
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  macOS Host                                         │
│  ├── appearance-watcher detects mode changes        │
│  ├── appearance get-mode / get-terminal-bg          │
│  └── Passes APPEARANCE_MODE, TERMINAL_BG via SSH    │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│  Remote (Linux/RPi)                                 │
│  ├── Reads env vars from SSH                        │
│  ├── appearance reload applies theme                │
│  └── No local detection needed                      │
└─────────────────────────────────────────────────────┘
```
