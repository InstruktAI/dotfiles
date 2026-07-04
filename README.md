# Dotfiles

Personal dotfiles for a consistent, powerful terminal environment across macOS and
Linux. The repo bootstraps a developer machine by installing tools, symlinking
configuration into place, and wiring up shell integrations. It is `zsh`-centric,
uses `tmux` for multiplexing, and synchronizes a dark/light appearance theme across
the terminal, tmux, and AI CLIs.

The setup is idempotent: `./install.sh` is safe to run repeatedly. It backs up
pre-existing files, reuses correct symlinks, and skips work already done.

## Installation

```bash
./install.sh                 # core setup, local defaults, Homebrew check
./install.sh --install-apps  # install missing Brewfile entries (no upgrades)
./install.sh --no-apps       # skip Homebrew entirely
./install.sh --no-defaults   # skip macOS defaults
```

`install.sh` delegates to `setup/bootstrap.sh`, which:

1. Installs Homebrew, Oh My Zsh, and Bun if missing.
2. Seeds machine-local override files from their tracked examples.
3. Runs `setup/install-core.sh` to create symlinks, wire `~/.zshrc`, and provision the
   appearance log directory. The appearance daemon/service tier is installed
   separately with `make install-runtime`.
4. Checks/installs Homebrew packages from `homebrew/Brewfile.local`.
5. Applies macOS defaults from `macos/defaults.local.sh`.

GPG key import stays manual — run `setup/import-gpg-key.sh` when needed.

## Repository Layout

| Path | Purpose |
|------|---------|
| `install.sh` | Public entrypoint; forwards to `setup/bootstrap.sh`. |
| `setup/` | Bootstrap and core install scripts, plus GPG key import/export. |
| `zsh/` | Modular zsh configuration, loaded in numeric order. |
| `appearance/` | Cross-platform dark/light appearance management. |
| `tmux/` | `tmux.conf`, symlinked to `~/.tmux.conf`. |
| `iterm2/` | iTerm2 preferences loaded from this custom folder on macOS. |
| `homebrew/` | `Brewfile` and the daily `brew-autoupdate` automation. |
| `macos/` | macOS system preference defaults (`defaults.sh`). |
| `.env` | Machine-local environment values (git-ignored) used at install time. |

### Local Overrides

The base configuration stays generic; machine-specific settings live in
git-ignored override files alongside their tracked `*.example.*` templates. The
installer copies each example into its real path on first run. Examples:

- `zsh/30-aliases.local.zsh`, `zsh/init.local.zsh` — extra shell config sourced by the base files.
- `macos/defaults.local.sh` — your machine's system preference defaults.
- `homebrew/Brewfile.local` — your machine's package list.
- `.env` — appearance coordinates and offsets read by the installer.

## `setup/`

The installation engine.

- `bootstrap.sh` — top-level orchestration (Homebrew/Oh My Zsh/Bun, local file
  seeding, brew bundle, macOS defaults).
- `install-core.sh` — user tier: idempotent symlinks, `~/.zshrc` activation block,
  iTerm2 prefs, and appearance log-directory provisioning.
- `install-runtime.sh` — daemon/service tier: launchd agents (Swift watcher + solar
  job) on macOS, or a systemd `--user` service on Linux. Run via `make install-runtime`.
- `import-gpg-key.sh` / `export-gpg-key.sh` — manual GPG key transfer helpers.

The `~/.zshrc` activation inserts a managed block after `source $ZSH/oh-my-zsh.sh`
so Oh My Zsh initializes first:

```zsh
# >>> instrukt dotfiles >>>
[[ -r "$HOME/.config/zsh/init.zsh" ]] && source "$HOME/.config/zsh/init.zsh"
# <<< instrukt dotfiles <<<
```

## `zsh/`

A modular zsh environment symlinked to `~/.config/zsh`. `init.zsh` sources the
numbered `.zsh` files in order; the numeric prefix encodes dependency order
(helpers before aliases before tool integrations).

| File | Responsibility |
|------|----------------|
| `00-helpers.zsh` | Helper functions used by later files. |
| `05-xdg-history.zsh` | XDG base dirs; standardized zsh history location. |
| `06-options.zsh` | Interactive behavior (history options, directory navigation). |
| `10-path.zsh` | `$PATH` management (Homebrew, Cargo, platform paths). |
| `12-brew.zsh` | Homebrew shell environment. |
| `15-completion-pre.zsh` | Completion system bootstrap. |
| `20-env.zsh` | Environment variables (editor, locale). |
| `25-secrets.zsh` | Placeholder for machine-specific secrets. |
| `30-aliases.zsh` | Aliases for git, docker, `eza`, navigation. |
| `32-macos.zsh` | macOS-specific shell tweaks. |
| `40-tools.zsh` | Integrations for `fzf`, `direnv`, `pipx`, etc. |
| `45-completion-aliases.zsh` | Maps command completions onto aliases. |
| `completions/` | Custom completion scripts. |
| `zshenv` | Symlinked to `~/.zshenv`; ensures PATH for non-interactive SSH shells. |

## `macos/`

macOS system preference defaults — nothing else lives here. This is the one directory
named after the OS rather than a tool, because its content genuinely *is* the
operating system's own settings (`defaults write`), with no third-party tool involved.

- `defaults.sh` — system preference defaults; copied to `defaults.local.sh` and applied during bootstrap.

## `iterm2/`

`com.googlecode.iterm2.plist` is loaded as iTerm2's custom preferences folder. On
macOS, `install-core.sh` points iTerm2 at this directory and enables loading prefs
from it.

## `tmux/`

`tmux.conf` — symlinked to `~/.tmux.conf` by `make install`. Plain tmux configuration
(keybindings, panes, mouse); it carries no appearance logic itself. `appearance reload`
sets the `@appearance_mode` tmux user option from outside this file.

## `homebrew/`

The Homebrew tool: the package list and its automation.

- `Brewfile` — tracked baseline package list; copied to `Brewfile.local` for the machine.
- `Brewfile.local` — your machine's package list (git-ignored).
- `bin/brew-autoupdate` — daily `brew update && brew upgrade --formula && brew upgrade --cask --greedy && brew cleanup`.
- `bin/brew-autoupdate-iterm` — launchd's entry point. Runs `brew-autoupdate` inside a
  minimized iTerm2 window instead of directly, so the macOS "App Management" TCC
  permission needed for cask upgrades scopes to iTerm2 (grant it once in System
  Settings → Privacy & Security → App Management) instead of to the bare shell
  interpreter, which would otherwise apply to every script on the machine.
- `launchd/ai.instrukt.brew-autoupdate.plist` — daily launchd agent, installed by
  `make install-runtime`.

---

## `appearance/` — Appearance Management

Cross-platform dark/light appearance management, synced across the terminal, tmux,
and CLI agent themes.

### Features

- **Automatic mode detection**: native OS signal (macOS Appearance, Linux desktop
  `color-scheme`) or solar (sunrise/sunset).
- **Terminal background detection**: Reads iTerm2 configuration on macOS.
- **Environment passthrough**: Host passes settings to remote sessions via SSH.
- **CLI theme sync**: Updates Claude, Antigravity CLI, and Codex themes.
- **System appearance automation**: macOS Appearance can follow sunrise/sunset
  with a configurable early-dark offset.

### Installation

Two tiers, both idempotent:

- **`make install`** symlinks `bin/appearance.py` to `~/.local/bin/appearance`, symlinks
  `tmux/tmux.conf` to `~/.tmux.conf`, and provisions the appearance log directory.
- **`make install-runtime`** installs the service tier: on macOS it compiles the Swift
  watcher and loads the launchd jobs (Appearance-change watcher + solar `apply-system`);
  on Linux it enables a systemd `--user` service running `appearance watch`.

`appearance` is a uv script. Its Python dependencies are declared inline in
`bin/appearance.py` and resolved by `uv run --script`; the installer does not
install Python packages. Runtime logging uses the InstruktAI log root, which must
be writable by the user running `appearance`; the logger creates the per-app
directory on first use.

### How It Works

#### Mode Detection Priority

Resolved behind a `Platform` seam (`MacOSPlatform` / `LinuxPlatform`):

1. `APPEARANCE_MODE` environment variable (e.g. forwarded from an SSH host)
2. The platform's native signal — macOS `AppleInterfaceStyle`; Linux freedesktop
   `color-scheme` via the XDG desktop portal, falling back to `gsettings`
3. Solar (sunrise/sunset) when the platform expresses no preference

#### macOS System Appearance Schedule

`appearance apply-system` drives the OS appearance from sunrise/sunset, once per genuine
crossing per day. On macOS the `ai.instrukt.appearance-system` LaunchAgent runs it every
five minutes; the Swift watcher then observes the Appearance change and syncs tmux plus
agent CLI themes. It is cross-platform — on Linux it sets `color-scheme` via `gsettings`.

The early-dark offsets default to 0. Set them in `.env` and re-run
`make install-runtime` to adjust. Neither launchd nor systemd reads shell startup files
or `.env` directly; `install-runtime.sh` renders the service definition from the current
shell environment first, then `.env`, then the installer defaults. Use
`APPEARANCE_DARK_OFFSET_MINUTES` for a year-round offset and
`APPEARANCE_DST_DARK_OFFSET_MINUTES` for extra offset only while local DST is active.

Effective dark start:

```text
dark_start = sunset
           - APPEARANCE_DARK_OFFSET_MINUTES
           - APPEARANCE_DST_DARK_OFFSET_MINUTES when local DST is active
```

#### Terminal Background Priority

1. `TERMINAL_BG` environment variable (from SSH host)
2. macOS: Read from iTerm2 plist configuration
3. Linux: Must be provided via environment (no local terminal)

#### SSH Integration

When SSHing from macOS to a remote machine, pass appearance settings:

```bash
APPEARANCE_MODE=$(appearance get-mode) \
TERMINAL_BG=$(appearance get-terminal-bg) \
ssh user@remote
```

TeleClaude does this automatically in `pane_manager.py`.

#### Agent CLI Theme Sync

`appearance reload` is imperative and idempotent. The current appearance mode is
the input, the agent table in `bin/appearance.py` defines the intended config value
for that mode, and each run writes that intended value. Re-running reload for the
same mode must converge to the same files even if a previous run, a sync conflict,
or a manual edit left stale state behind.

Per-agent preference memory may exist, but it is not authoritative. State may only
remember a user preference when the current agent config differs from the last
value that `appearance reload` applied. That proves the user or the agent changed
the theme outside the sync path. On the next reload, the script records that
external change as the preference for the mode that was active when the last value
was applied, then writes the intended value for the newly detected mode.

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
`appearance/agent_state.json`, which is created on first reload when absent.

This contract applies to every synced agent. For each agent, mode-only fields that
accept only `dark` or `light` write the current mode directly and do not learn
arbitrary preferences. Agents with real named themes may use preference memory,
provided their `last_applied` check prevents stale state from overriding the
imperative mode-to-theme mapping.

### Commands

```bash
appearance get-mode         # Output: dark or light
appearance get-terminal-bg  # Output: #rrggbb
appearance reload           # Reload all themes
appearance apply-system     # Drive OS appearance from the solar schedule
appearance watch            # Linux run loop: poll every 5m, reload on change
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APPEARANCE_MODE` | (detected) | Override mode: `dark` or `light` |
| `TERMINAL_BG` | (detected) | Override terminal background: `#rrggbb` |
| `APPEARANCE_LATITUDE` | 52.37 | Latitude for sunrise/sunset |
| `APPEARANCE_LONGITUDE` | 4.89 | Longitude for sunrise/sunset |
| `APPEARANCE_DARK_OFFSET_MINUTES` | 0 | Always start dark mode this many minutes before sunset |
| `APPEARANCE_DST_DARK_OFFSET_MINUTES` | 0 | Extra dark offset while local DST is active |
| `APPEARANCE_CACHE_DIR` | `/tmp` | Directory for date/location-keyed sunrise/sunset cache files |
| `APPEARANCE_LOG_LEVEL` | INFO | Logger level: DEBUG/INFO/WARNING/ERROR |
| `INSTRUKT_AI_LOG_ROOT` | `/var/log/instrukt-ai` | Override root for InstruktAI logs |

Runtime logs are written through `instrukt_ai_logging` and read with
`instrukt-ai-logs appearance`. The default log file is
`/var/log/instrukt-ai/appearance/appearance.log`; when `INSTRUKT_AI_LOG_ROOT` is
set, the file is `$INSTRUKT_AI_LOG_ROOT/appearance/appearance.log`.

### Files

```
appearance/
├── bin/
│   ├── appearance.py            # Main script (uv/python); symlinked to ~/.local/bin/appearance
│   └── appearance-watcher.swift # macOS watcher (Swift)
├── launchd/                     # macOS service tier
│   ├── ai.instrukt.appearance-system.plist
│   └── ai.instrukt.appearance-watcher.plist
├── systemd/
│   └── appearance.service       # Linux service tier (systemd --user)
└── agent_state.json             # Local ignored preference memory/provenance
```

### Architecture

```
macOS host
  ├── Swift watcher detects OS Appearance changes (event-driven) → appearance reload
  ├── launchd runs apply-system every 5m for the solar offset
  └── appearance get-mode / get-terminal-bg; may forward APPEARANCE_MODE/TERMINAL_BG over SSH

Linux / RPi
  ├── Platform seam detects mode: freedesktop color-scheme (portal/gsettings) or solar
  ├── systemd --user service polls every 5m and reloads on change
  └── also accepts APPEARANCE_MODE/TERMINAL_BG forwarded over SSH
```
