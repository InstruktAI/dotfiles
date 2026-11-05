# Dotfiles

Personal dotfiles for a consistent terminal environment across macOS and Linux,
managed with [chezmoi](https://www.chezmoi.io/). It is `zsh`-centric, uses
`tmux` for multiplexing, synchronizes a dark/light appearance theme across the
terminal, tmux and AI CLIs, and keeps every machine on the same configuration by
pulling it from git.

## Installation

```bash
chezmoi init --apply InstruktAI/dotfiles
```

This clones the repository to `~/.local/share/chezmoi`, writes the machine's
chezmoi config (`~/.config/chezmoi/chezmoi.toml`) from
`home/.chezmoi.toml.tmpl`, and applies the source: files land in `~`, then the
install scripts run. Get `chezmoi` itself from Homebrew (`brew install chezmoi`)
or `sh -c "$(curl -fsLS get.chezmoi.io)"`; the Brewfile keeps it updated after
that.

Re-running `chezmoi apply` is always safe. Useful variants:

```bash
chezmoi apply --exclude=scripts   # files only: no installers, packages or defaults
chezmoi diff                      # what apply would change in ~
chezmoi status                    # pending changes; `R` lines are scripts that will run
dotfiles-brew diff                # Brewfile entries not yet installed
dotfiles-brew upgrade             # upgrade formulae, holding back major bumps and casks
```

### Changing the configuration

The source in git is the only place to change anything. Never edit a managed
file in `~`: the next `chezmoi apply` or scheduled update overwrites it.

```bash
chezmoi cd            # shell in the source working tree (~/.local/share/chezmoi)
chezmoi edit ~/.tmux.conf   # or edit the source file for a target directly
chezmoi apply         # apply locally, then commit and push from the working tree
```

Other machines pick the change up through the scheduled update (below).

### Scheduled update

Every machine runs `chezmoi update --no-tty --force` on a schedule — a launchd
agent (`ai.instrukt.chezmoi-update`) on macOS, a systemd `--user` timer
(`chezmoi-update.timer`) on Linux, every `update.interval_seconds` (default one
hour). It pulls the source from git and applies it.

The scheduled run sets `DOTFILES_UNATTENDED=1`. Scripts that need a person —
installing Homebrew, Oh My Zsh or Bun, `brew bundle`, macOS defaults (sudo,
Full Disk Access prompts), the Linux Beszel agent install (sudo) and reloading
the update agent itself — render empty then, so chezmoi skips them and runs
them at the next interactive `chezmoi apply`. `chezmoi status` lists them as
pending (`R`). Service definitions and their reloads, the iTerm2 preferences
folder and the macOS Beszel agent do apply unattended.

On Linux, user timers run only while the user has a session unless lingering is
enabled: `sudo loginctl enable-linger "$USER"`.

### Secrets (age)

Secrets live in the source as age-encrypted files and are decrypted on apply.
Today that is `~/.config/zsh/25-secrets.local.zsh` (sourced by
`25-secrets.zsh`) and the Beszel agent token `~/.config/beszel/token`.

The one manual step per machine is placing the age identity:

```bash
mkdir -p ~/.config/chezmoi
# copy the shared identity file (from your password manager) to:
#   ~/.config/chezmoi/key.txt   (mode 600)
chezmoi init          # regenerates the config with encryption enabled
chezmoi apply
```

The config template always configures `encryption = "age"` with the identity
at `~/.config/chezmoi/key.txt`, and reads the recipient (needed only to
encrypt) from the `# public key: age1…` line `age-keygen` writes into it. Until
a machine holds the identity, the encrypted targets are skipped and everything
else applies.

Creating the identity once, and adding or changing a secret:

```bash
chezmoi age-keygen --output ~/.config/chezmoi/key.txt   # once, for all machines
chezmoi add --encrypt ~/.config/zsh/25-secrets.local.zsh
chezmoi add --encrypt ~/.config/beszel/token
```

### Machine-local data

Machines differ only through chezmoi data. Defaults for every machine are in
`home/.chezmoidata/defaults.toml`. A machine overrides or extends them under
`[data]` in its own `~/.config/chezmoi/chezmoi.toml` (`chezmoi edit-config`);
chezmoi deep-merges that over the defaults, and `chezmoi init` carries it over
when it regenerates the config.

| Key | Default | Purpose |
|-----|---------|---------|
| `appearance.latitude`, `appearance.longitude` | unset | Explicit coordinates for sunrise/sunset. Unset: derived from the time zone. Machine-local only; never commit coordinates. |
| `appearance.dark_offset_minutes` | source default | Start dark mode this many minutes before sunset. |
| `appearance.dst_dark_offset_minutes` | source default | Extra minutes while local DST is active. |
| `macos.battery_sleep_minutes` | unset | Idle minutes before a laptop sleeps on battery. Unset: never sleeps, like on AC. |
| `zsh.dir_aliases` | `cdw`, `cdi` | `alias name="cd ~/<dir>"`, defined when the directory exists. |
| `profile` | `server` | The machine's role: `workstation` or `server`. Only a workstation gets `Brewfile.workstation`. |
| `beszel.key` | empty | The Beszel hub's public key. Setting it installs the agent. |
| `beszel.hub_url` | empty | The Beszel hub URL (`HUB_URL`). |
| `beszel.listen` | source default | Agent port or address (`LISTEN`). |
| `update.interval_seconds` | source default | Scheduled update interval. |

Example:

```toml
[data.appearance]
    latitude = 0.0
    longitude = 0.0
[data.zsh.dir_aliases]
    cdp = "Projects"
[data.beszel]
    key = "ssh-ed25519 AAAA…"
    hub_url = "http://<hub>:8090"
```

## Repository Layout

The repository root holds project files; `.chezmoiroot` points chezmoi at
`home/`, the source state.

| Path | Purpose |
|------|---------|
| `home/` | chezmoi source state: every file here maps to a target in `~`. |
| `home/.chezmoi.toml.tmpl` | Template for each machine's chezmoi config (age, carried-over data). |
| `home/.chezmoidata/defaults.toml` | Data defaults for all machines. |
| `home/.chezmoiignore` | Per-OS and per-machine exclusions. |
| `home/.chezmoiscripts/` | Install and service scripts (`run_once_`/`run_onchange_`). |
| `home/.chezmoitemplates/` | Shared template fragments. |
| `home/modify_dot_zshrc` | Manages one block inside `~/.zshrc`. |
| `home/dot_config/zsh/` | Modular zsh configuration → `~/.config/zsh`. |
| `home/dot_config/homebrew/` | `Brewfile.common` (every machine), `Brewfile.macos` (every Mac) and `Brewfile.workstation` (workstations) → `~/.config/homebrew`. |
| `home/dot_local/bin/` | `appearance`, `dotfiles-brew`, `brew-autoupdate*` → `~/.local/bin`. |
| `home/dot_local/libexec/appearance/` | macOS appearance watcher (binary and Swift source). |
| `home/Library/LaunchAgents/` | macOS launchd agents (templates). |
| `home/dot_config/systemd/user/` | Linux systemd `--user` units (templates). |
| `iterm2/` | iTerm2 preferences folder (macOS), read and written in the working tree. |
| `setup/` | Manual GPG key import/export helpers. |

### What applying does

1. **Before files:** installs Homebrew and Oh My Zsh when missing.
2. **Files:** the zsh config (`~/.config/zsh`, `~/.zshenv`), the managed block in
   `~/.zshrc`, `~/.tmux.conf`, the appearance tool and its config, the
   Brewfiles, the helper scripts, the launchd agents (macOS) or systemd units
   (Linux), and the decrypted secrets.
3. **After files:** installs Bun when missing; installs missing Brewfile entries
   whenever a Brewfile changes (and keeps `node` on the v24 line); points iTerm2
   at `iterm2/` (macOS); applies macOS defaults when they change; reloads each
   launchd agent or restarts each systemd unit whose definition changed; installs
   or restarts the Beszel agent when its configuration changes.

`~/.zshrc` stays the machine's own file (Oh My Zsh theme, plugins, lines that
tool installers append). chezmoi only keeps this block in it, after
`source $ZSH/oh-my-zsh.sh`:

```zsh
# >>> instrukt dotfiles >>>
[[ -r "$HOME/.config/zsh/init.zsh" ]] && source "$HOME/.config/zsh/init.zsh"
# <<< instrukt dotfiles <<<
```

GPG key import stays manual — run `setup/import-gpg-key.sh` when needed.

## zsh

A modular zsh environment in `~/.config/zsh`. `init.zsh` sources the numbered
`.zsh` files in order; the numeric prefix encodes dependency order (helpers
before aliases before tool integrations).

| File | Responsibility |
|------|----------------|
| `00-helpers.zsh` | Helper functions used by later files. |
| `05-xdg-history.zsh` | XDG base dirs; standardized zsh history location. |
| `06-options.zsh` | Interactive behavior (history options, directory navigation). |
| `10-path.zsh` | `$PATH` management (Homebrew, Cargo, platform paths). |
| `12-brew.zsh` | Homebrew shell environment. |
| `15-completion-pre.zsh` | Completion system bootstrap. |
| `20-env.zsh` | Environment variables (editor, locale). |
| `25-secrets.zsh` | Sources the decrypted `25-secrets.local.zsh`. |
| `30-aliases.zsh` | Aliases for git, docker, `eza`, navigation, and the data-driven directory aliases. |
| `32-macos.zsh` | macOS-specific shell tweaks. |
| `40-tools.zsh` | Integrations for `fzf`, `direnv`, `pipx`, etc. |
| `45-completion-aliases.zsh` | Maps command completions onto aliases. |
| `completions/` | Custom completion scripts. |
| `~/.zshenv` | Ensures PATH for non-interactive SSH shells. |

## macOS defaults

`home/.chezmoiscripts/run_onchange_after_40-macos-defaults.sh.tmpl` holds the
system preference defaults (`defaults write`) plus the locale from chezmoi data.
It runs whenever its rendered content changes, from an interactive apply only.

## iTerm2

iTerm2 loads its preferences from `iterm2/` in the chezmoi working tree
(`PrefsCustomFolder`), and saves changes there. Commit them from the working
tree like any other change.

## tmux

`~/.tmux.conf` — plain tmux configuration (keybindings, panes, mouse); it carries
no appearance logic itself. `appearance reload` sets the `@appearance_mode` tmux
user option from outside this file.

## Homebrew

- `Brewfile.common` — baseline package list for every OS Homebrew supports.
- `Brewfile.macos` — GNU-userland overrides (macOS ships BSD tools; Linux
  already has GNU natively), the terminal and Keychain integration; every Mac.
- `Brewfile.workstation` — what only a workstation needs: language toolchains,
  media and document tools, and on macOS the desktop apps; deployed only where
  the machine's data sets `profile = "workstation"`.
- The Brewfiles are a floor, not a mirror: installing adds what is missing and
  never removes anything, so a package installed by hand on one machine stays.
- `dotfiles-brew install|diff|upgrade` — installs missing entries (chezmoi runs it
  when a Brewfile changes), shows what install would add, or upgrades formulae
  while holding back major-version bumps and casks.
- `brew-autoupdate` — daily `brew update && brew upgrade --formula && brew upgrade --cask --greedy && brew cleanup`.
- `brew-autoupdate-iterm` — launchd's entry point. Runs `brew-autoupdate` inside a
  minimized iTerm2 window instead of directly, so the macOS "App Management" TCC
  permission needed for cask upgrades scopes to iTerm2 (grant it once in System
  Settings → Privacy & Security → App Management) instead of to the bare shell
  interpreter, which would otherwise apply to every script on the machine.
- `ai.instrukt.brew-autoupdate` — the daily launchd agent.

## Beszel agent

Machines whose chezmoi data sets `beszel.key` run the
[Beszel](https://beszel.dev) monitoring agent, installed the way
[its guide](https://www.beszel.dev/guide/agent-installation) describes:

- **macOS:** the `henrygd/beszel` Homebrew tap, `beszel-agent`, run by
  `brew services`. chezmoi renders `~/.config/beszel/beszel-agent.env` (`KEY`,
  `LISTEN`, `HUB_URL`, and `TOKEN_FILE` when a token is present). Logs:
  `~/.cache/beszel/beszel-agent.log`.
- **Linux:** the official `get.beszel.dev` install script, which installs the
  binary, a `beszel` system user and the `beszel-agent` systemd service with
  daily auto-update; it receives `KEY` and the port. `HUB_URL` and `TOKEN_FILE`
  are set in the drop-in `/etc/systemd/system/beszel-agent.service.d/10-dotfiles.conf`,
  rewritten on every change, and the token is copied to
  `/etc/beszel-agent/token` (root:beszel, 0640) — never passed on a command line
  or written into the world-readable unit. It needs sudo, so it runs from an
  interactive apply.

`KEY` (the hub's public key) and `HUB_URL` are not secret and are machine data.
The registration token is a secret: it is the encrypted `~/.config/beszel/token`,
used only on machines that hold the age identity. The agent is reinstalled or
restarted whenever any of these change.

---

## Appearance Management

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

chezmoi installs `appearance` to `~/.local/bin/appearance`, renders its config to
`~/.config/appearance/config.toml`, and installs the service tier: on macOS the
launchd agents (the Swift Appearance-change watcher at
`~/.local/libexec/appearance/appearance-watcher` and the solar `apply-system` job);
on Linux a systemd `--user` service running `appearance watch`.

`appearance` is a uv script. Its Python dependencies are declared inline in the
script and resolved by `uv run --script`. Runtime logging uses the InstruktAI
log root, which must be writable by the user running `appearance`; the logger
creates the per-app directory on first use.

### How It Works

#### Mode Detection Priority

Resolved behind a `Platform` seam (`MacOSPlatform` / `LinuxPlatform`):

1. `APPEARANCE_MODE` environment variable (e.g. forwarded from an SSH host)
2. The platform's native signal — macOS `AppleInterfaceStyle`; Linux freedesktop
   `color-scheme` via the XDG desktop portal, falling back to `gsettings`
3. Solar (sunrise/sunset) when the platform expresses no preference

#### Location for the solar schedule

The coordinates for sunrise/sunset resolve in this order, the same on macOS and
Linux, without permissions or network:

1. Explicit coordinates: `APPEARANCE_LATITUDE`/`APPEARANCE_LONGITUDE`, else
   `[location]` in `~/.config/appearance/config.toml` (rendered from the
   machine's `appearance.latitude`/`appearance.longitude` chezmoi data).
2. The current time zone's reference location from the tz database
   (`zone1970.tab`, then `zone.tab`, under `/usr/share/zoneinfo`, following
   `tzdata.zi` links). The zone comes from `TZ`, else the `/etc/localtime`
   link, else `timedatectl` on Linux.
3. None — a zone without a location (e.g. `UTC`) or no tz database: no solar
   switching. This is logged once (`solar_switching_disabled`), not on every run.

Sunrise and sunset times themselves come from the sunrise-sunset.org API,
cached per day and location.

#### macOS System Appearance Schedule

`appearance apply-system` drives the OS appearance from sunrise/sunset, once per genuine
crossing per day. On macOS the `ai.instrukt.appearance-system` LaunchAgent runs it every
five minutes; the Swift watcher then observes the Appearance change and syncs tmux plus
agent CLI themes. It is cross-platform — on Linux it sets `color-scheme` via `gsettings`.

The early-dark offsets default to the values in `home/.chezmoidata/defaults.toml`
and can be overridden per machine through chezmoi data (see Machine-local data).
`appearance` reads them from its config file on every run; an environment
variable of the same name overrides the file.

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
the input, the agent table in `appearance` defines the intended config value
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
`appearance`:

| Agent | Settings file | Theme field |
|-------|---------------|-------------|
| Claude | `~/.claude/settings.json` | `theme` |
| Claude | `~/.claude.json` | `theme` |
| Antigravity CLI | `~/.gemini/antigravity-cli/settings.json` | `colorScheme` |
| Codex | `~/.codex/config.toml` | `[tui].theme` |

Preference memory and last-applied provenance live in
`$XDG_STATE_HOME/appearance/agent_state.json` (default
`~/.local/state/appearance/agent_state.json`), created on first reload when absent.

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
| `APPEARANCE_LATITUDE` | config file, else time zone | Latitude for sunrise/sunset |
| `APPEARANCE_LONGITUDE` | config file, else time zone | Longitude for sunrise/sunset |
| `APPEARANCE_DARK_OFFSET_MINUTES` | config file, else 0 | Always start dark mode this many minutes before sunset |
| `APPEARANCE_DST_DARK_OFFSET_MINUTES` | config file, else 0 | Extra dark offset while local DST is active |
| `APPEARANCE_CONFIG` | `$XDG_CONFIG_HOME/appearance/config.toml` | Config file rendered by chezmoi |
| `APPEARANCE_CACHE_DIR` | `/tmp` | Directory for date/location-keyed sunrise/sunset cache files |
| `APPEARANCE_STATE_DIR` | `$XDG_STATE_HOME/appearance` | Transition state and agent theme memory |
| `APPEARANCE_LOG_LEVEL` | INFO | Logger level: DEBUG/INFO/WARNING/ERROR |
| `XDG_STATE_HOME` | `~/.local/state` | Override state root for InstruktAI logs |

Runtime logs are written through `instrukt_ai_logging` and read with
`instrukt-ai-logs appearance`. The log file is
`$XDG_STATE_HOME/instrukt-ai/appearance/appearance.log` (default
`~/.local/state/instrukt-ai/appearance/appearance.log`).

### Files

```
home/
├── dot_local/bin/executable_appearance            # → ~/.local/bin/appearance (uv/python)
├── dot_local/libexec/appearance/                  # → ~/.local/libexec/appearance (macOS)
│   ├── executable_appearance-watcher              #   compiled Swift watcher
│   └── appearance-watcher.swift
├── dot_config/appearance/config.toml.tmpl         # → ~/.config/appearance/config.toml
├── Library/LaunchAgents/
│   ├── ai.instrukt.appearance-system.plist.tmpl   # macOS solar job
│   └── ai.instrukt.appearance-watcher.plist.tmpl  # macOS watcher
└── dot_config/systemd/user/appearance.service.tmpl  # Linux service
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
