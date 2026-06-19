# Terminal Appearance Setup

Cross-platform terminal/tmux appearance management with automatic dark/light mode switching.

## Features

- **Automatic mode detection**: macOS system preferences or sunrise/sunset API
- **Terminal background detection**: Reads iTerm2 configuration on macOS
- **Environment passthrough**: Host passes settings to remote sessions via SSH
- **tmux theming**: Dynamic borders, status bar, and pane styling
- **CLI theme sync**: Updates Claude, Antigravity CLI, and Codex themes
- **System appearance automation**: macOS Appearance can follow sunrise/sunset
  with a configurable early-dark offset

## Installation

```bash
./install.sh
```

This will:
1. Symlink `bin/appearance` to `~/.local/bin/`
2. Symlink `tmux.conf` to `~/.tmux.conf`
3. On macOS: compile the Swift watcher and install launchd jobs for watching
   macOS Appearance changes and applying the solar appearance schedule

`appearance` is a uv script. Its Python dependencies are declared inline in
`bin/appearance.py` and resolved by `uv run --script`; the installer does not
install Python packages. Runtime logging uses the InstruktAI log root, which
must be writable by the user running `appearance`; the logger creates the
per-app directory on first use.

## How It Works

### Mode Detection Priority

1. `APPEARANCE_MODE` environment variable (from SSH host)
2. macOS: `defaults read -g AppleInterfaceStyle`
3. Linux: Sunrise/sunset API based on location

### macOS System Appearance Schedule

`appearance apply-system` sets macOS Appearance itself from sunrise/sunset. The
installed `ai.instrukt.appearance-system` LaunchAgent runs it every five
minutes. By default, it adds a 60 minute early-dark correction only while the
local timezone is in daylight saving time:

```xml
<key>APPEARANCE_DST_DARK_OFFSET_MINUTES</key>
<string>60</string>
```

Change that value in
`.env` and re-run `./install.sh` to adjust the DST correction. `launchd` does
not read shell startup files or `.env` directly; `install.sh` renders the
LaunchAgent plist from the current shell environment first, then `.env`, then
the defaults in the installer. Use `APPEARANCE_DARK_OFFSET_MINUTES` only for a
year-round offset. The existing watcher then observes the macOS Appearance
change and syncs tmux plus agent CLI themes.

Effective dark start:

```text
dark_start = sunset
           - APPEARANCE_DARK_OFFSET_MINUTES
           - APPEARANCE_DST_DARK_OFFSET_MINUTES when local DST is active
```

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

Preference memory and last-applied provenance live in the local, git-ignored
`terminal/agent_state.json`, which is created on first reload when absent.

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
appearance apply-system     # Set macOS Appearance from solar schedule
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
| `APPEARANCE_DARK_OFFSET_MINUTES` | 0 | Always start dark mode this many minutes before sunset |
| `APPEARANCE_DST_DARK_OFFSET_MINUTES` | 0 | Extra dark offset while local DST is active |
| `APPEARANCE_CACHE_DIR` | `/tmp` | Directory for date/location-keyed sunrise/sunset cache files |
| `APPEARANCE_BORDER_PERCENT` | 15 | Border blend percentage |
| `APPEARANCE_STATUS_BG_PERCENT` | 10 | Status bar background blend |
| `APPEARANCE_STATUS_FG_PERCENT` | 40 | Status bar foreground blend |
| `APPEARANCE_FOCUS_DIM_PERCENT` | 10 | Inactive pane dim percentage |
| `APPEARANCE_LOG` | 1 | Enable `appearance` runtime logging |
| `INSTRUKT_AI_LOG_ROOT` | `/var/log/instrukt-ai` | Override root for InstruktAI logs |

Runtime logs are written through `instrukt_ai_logging` and read with
`instrukt-ai-logs appearance`. The default log file is
`/var/log/instrukt-ai/appearance/appearance.log`; when
`INSTRUKT_AI_LOG_ROOT` is set, the file is
`$INSTRUKT_AI_LOG_ROOT/appearance/appearance.log`.

## Files

```
terminal/
├── bin/
│   ├── appearance              # Main script (python)
│   └── appearance-watcher.swift # macOS watcher (Swift)
├── launchd/
│   ├── ai.instrukt.appearance-system.plist
│   └── ai.instrukt.appearance-watcher.plist
├── agent_state.json            # Local ignored preference memory/provenance
├── tmux.conf                   # Shared tmux configuration
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
