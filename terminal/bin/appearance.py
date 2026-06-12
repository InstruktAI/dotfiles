#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "instruktai-python-logger",
# ]
# ///
"""Unified appearance management - OS agnostic.
Subcommands: get-mode, get-terminal-bg, reload, watch
"""

from __future__ import annotations

import sys

import datetime
import json
import os
import plistlib
import re
import subprocess
import time
import tomllib
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional

from instrukt_ai_logging import configure_logging, get_logger

SCRIPT_DIR = Path(__file__).resolve().parent

APPEARANCE_LATITUDE = os.environ.get("APPEARANCE_LATITUDE", "52.37")
APPEARANCE_LONGITUDE = os.environ.get("APPEARANCE_LONGITUDE", "4.89")
APPEARANCE_DARK_OFFSET_MINUTES = os.environ.get("APPEARANCE_DARK_OFFSET_MINUTES", "0")
APPEARANCE_DST_DARK_OFFSET_MINUTES = os.environ.get("APPEARANCE_DST_DARK_OFFSET_MINUTES", "0")
APPEARANCE_CACHE_DIR = os.environ.get("APPEARANCE_CACHE_DIR", "/tmp")
APPEARANCE_LOG = os.environ.get("APPEARANCE_LOG", "1")

DEFAULT_PATH_PREFIX = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
os.environ["PATH"] = f"{DEFAULT_PATH_PREFIX}:{os.environ.get('PATH', '')}"

configure_logging("appearance")
LOGGER = get_logger("appearance")


def log(message: str) -> None:
    if APPEARANCE_LOG != "1":
        return
    LOGGER.info("event", detail=message)


def is_macos() -> bool:
    return sys.platform == "darwin"


def run_command(
    args: list[str], check: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, capture_output=True, text=True)


def parse_minutes(value: str) -> int:
    try:
        minutes = int(value)
    except ValueError:
        return 0
    return max(0, minutes)


def is_local_dst_active() -> bool:
    return time.localtime().tm_isdst > 0


def dark_offset() -> datetime.timedelta:
    minutes = parse_minutes(APPEARANCE_DARK_OFFSET_MINUTES)
    if is_local_dst_active():
        minutes += parse_minutes(APPEARANCE_DST_DARK_OFFSET_MINUTES)
    return datetime.timedelta(minutes=minutes)


def parse_coordinate(value: str, *, minimum: float, maximum: float, name: str) -> float | None:
    try:
        coordinate = float(value)
    except ValueError:
        log(f"is_daylight invalid {name} value={value}")
        return None
    if minimum <= coordinate <= maximum:
        return coordinate
    log(f"is_daylight invalid {name} value={value}")
    return None


def solar_cache_file(latitude: float, longitude: float) -> Path:
    date_key = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    lat_key = f"{latitude:.4f}".replace("-", "m").replace(".", "_")
    lng_key = f"{longitude:.4f}".replace("-", "m").replace(".", "_")
    return Path(APPEARANCE_CACHE_DIR) / f"sunrise-sunset-{date_key}-{lat_key}-{lng_key}.json"


def is_daylight(*, allow_fallback: bool = True) -> bool | None:
    latitude = parse_coordinate(APPEARANCE_LATITUDE, minimum=-90.0, maximum=90.0, name="latitude")
    longitude = parse_coordinate(APPEARANCE_LONGITUDE, minimum=-180.0, maximum=180.0, name="longitude")
    if latitude is None or longitude is None:
        if not allow_fallback:
            return None
        hour = datetime.datetime.now().hour
        daylight = 6 <= hour < 18
        log(f"is_daylight using hour fallback daylight={daylight}")
        return daylight

    cache_file = solar_cache_file(latitude, longitude)
    cache_max_age = 86400

    def parse_solar_time(value: str) -> Optional[datetime.datetime]:
        try:
            return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None

    def is_now_between(sunrise: str, sunset: str) -> bool:
        sunrise_time = parse_solar_time(sunrise)
        sunset_time = parse_solar_time(sunset)
        if sunrise_time is None or sunset_time is None:
            return False
        dark_start = sunset_time - dark_offset()
        now = datetime.datetime.now(datetime.timezone.utc)
        return sunrise_time < now < dark_start

    if cache_file.exists():
        age = int(time.time() - cache_file.stat().st_mtime)
        if age < cache_max_age:
            try:
                data = json.loads(cache_file.read_text(encoding="utf-8"))
                results = data.get("results", {})
                sunrise = results.get("sunrise")
                sunset = results.get("sunset")
                if sunrise and sunset:
                    daylight = is_now_between(sunrise, sunset)
                    log("is_daylight using cached sunrise-sunset data")
                    return daylight
            except Exception as exc:
                log(f"is_daylight cache read failed error={exc}")

    url = (
        "https://api.sunrise-sunset.org/json"
        f"?lat={latitude}&lng={longitude}&formatted=0"
    )
    try:
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "dotfiles-appearance/1.0"},
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            payload = response.read().decode("utf-8")
        data = json.loads(payload)
        if data.get("status") == "OK":
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            cache_file.write_text(json.dumps(data), encoding="utf-8")
            results = data.get("results", {})
            sunrise = results.get("sunrise")
            sunset = results.get("sunset")
            if sunrise and sunset:
                daylight = is_now_between(sunrise, sunset)
                log("is_daylight using live sunrise-sunset data")
                return daylight
        log(f"is_daylight sunrise-sunset API returned status={data.get('status')}")
    except Exception as exc:
        log(f"is_daylight sunrise-sunset API failed error={exc}")

    if not allow_fallback:
        return None
    hour = datetime.datetime.now().hour
    daylight = 6 <= hour < 18
    log(f"is_daylight using hour fallback daylight={daylight}")
    return daylight


def get_solar_mode(*, allow_fallback: bool = True) -> str | None:
    offset = dark_offset()
    daylight = is_daylight(allow_fallback=allow_fallback)
    if daylight is None:
        log(f"get_solar_mode unavailable dark_offset_minutes={int(offset.total_seconds() / 60)}")
        return None
    if daylight:
        log(f"get_solar_mode detected light from sunrise-sunset dark_offset_minutes={int(offset.total_seconds() / 60)}")
        return "light"
    log(f"get_solar_mode detected dark from sunrise-sunset dark_offset_minutes={int(offset.total_seconds() / 60)}")
    return "dark"


def get_mode() -> str:
    env_mode = os.environ.get("APPEARANCE_MODE")
    if env_mode:
        log(f"get_mode using APPEARANCE_MODE={env_mode}")
        return env_mode

    if is_macos():
        mode = get_macos_appearance_mode()
        log(f"get_mode detected {mode} from macOS defaults")
        return mode

    mode = get_solar_mode()
    if mode is None:
        mode = "light"
        log("get_mode defaulting to light because solar mode is unavailable")
    log(f"get_mode detected {mode} from sunrise-sunset")
    return mode


def get_macos_appearance_mode() -> str:
    try:
        result = run_command(["defaults", "read", "-g", "AppleInterfaceStyle"])
        if result.returncode == 0 and "Dark" in result.stdout:
            return "dark"
    except Exception:
        pass
    return "light"


def set_macos_appearance(mode: str) -> bool:
    if mode not in {"dark", "light"}:
        return False
    current = get_macos_appearance_mode()
    if current == mode:
        log(f"apply_system macOS appearance already mode={mode}")
        return True
    enabled = "true" if mode == "dark" else "false"
    result = run_command(
        [
            "osascript",
            "-e",
            f'tell application "System Events" to tell appearance preferences to set dark mode to {enabled}',
        ]
    )
    if result.returncode != 0:
        log(f"apply_system failed mode={mode} error={result.stderr.strip()}")
        return False
    log(f"apply_system set macOS appearance mode={mode}")
    return True


# ---------------------------------------------------------------------------
# iTerm terminal background detection
# ---------------------------------------------------------------------------


def load_iterm_plist() -> Optional[Dict[str, Any]]:
    plist_path = Path.home() / "Library" / "Preferences" / "com.googlecode.iterm2.plist"
    if plist_path.exists():
        try:
            with plist_path.open("rb") as handle:
                return plistlib.load(handle)
        except Exception:
            pass

    try:
        result = subprocess.run(
            ["defaults", "export", "com.googlecode.iterm2", "-"],
            capture_output=True,
        )
        if result.returncode != 0:
            return None
        return plistlib.loads(result.stdout)
    except Exception:
        return None


def component_value(color: Dict[str, Any], key: str) -> int:
    value = color.get(key, 0)
    try:
        if isinstance(value, str):
            value = float(value)
        value = float(value)
    except Exception:
        value = 0
    return max(0, min(255, int(value * 255)))


def get_terminal_bg_from_iterm(is_dark: bool) -> Optional[str]:
    plist = load_iterm_plist()
    if not plist:
        return None

    bookmarks = plist.get("New Bookmarks", [])
    if not bookmarks:
        return None

    profile_name = os.environ.get("ITERM_PROFILE", "Default")
    profile = None
    for entry in bookmarks:
        if entry.get("Name") == profile_name:
            profile = entry
            break
    if profile is None:
        profile = bookmarks[0]

    uses_separate = bool(
        profile.get("Use Separate Colors for Light and Dark Mode", False)
    )
    if uses_separate:
        mode_suffix = "Dark" if is_dark else "Light"
        key = f"Background Color ({mode_suffix})"
    else:
        key = "Background Color"

    bg = profile.get(key) or {}
    if not bg:
        return None

    red = component_value(bg, "Red Component")
    green = component_value(bg, "Green Component")
    blue = component_value(bg, "Blue Component")
    return f"#{red:02x}{green:02x}{blue:02x}"


def get_terminal_bg() -> Optional[str]:
    env_bg = os.environ.get("TERMINAL_BG")
    if env_bg:
        log(f"get_terminal_bg using TERMINAL_BG={env_bg}")
        return env_bg

    if is_macos():
        mode = get_mode()
        is_dark = mode == "dark"
        bg = get_terminal_bg_from_iterm(is_dark)
        if bg:
            log("get_terminal_bg detected from iTerm profile")
            return bg

    return None


# ---------------------------------------------------------------------------
# Agent theme sync (data-driven)
# ---------------------------------------------------------------------------


def _normalize_mode(value: object) -> str | None:
    if isinstance(value, str) and value in {"dark", "light"}:
        return value
    return None


def _normalize_theme(value: object) -> str | None:
    if isinstance(value, str):
        stripped = value.strip()
        if stripped:
            return stripped
    return None


@dataclass
class AgentThemeConfig:
    key: str
    files: list[Path]
    theme_path: list[str]
    defaults: dict[str, str] = field(default_factory=dict)
    fmt: str = "json"  # "json" or "toml" — selects the read/write codec
    mode_only: bool = False


AGENTS: list[AgentThemeConfig] = [
    AgentThemeConfig(
        key="claude",
        files=[Path.home() / ".claude" / "settings.json", Path.home() / ".claude.json"],
        theme_path=["theme"],
        defaults={"dark": "dark", "light": "light"},
    ),
    # Antigravity CLI ("agy") replaced the legacy Gemini CLI: settings moved to
    # antigravity-cli/settings.json and the theme key is top-level "colorScheme"
    # with plain "dark"/"light" values (was ui.theme = Default/Default Light).
    AgentThemeConfig(
        key="gemini",
        files=[Path.home() / ".gemini" / "antigravity-cli" / "settings.json"],
        theme_path=["colorScheme"],
        defaults={"dark": "dark", "light": "light"},
        mode_only=True,
    ),
    # Codex stores its TUI theme as kebab-case `theme` under [tui] in config.toml.
    AgentThemeConfig(
        key="codex",
        files=[Path.home() / ".codex" / "config.toml"],
        theme_path=["tui", "theme"],
        defaults={"dark": "one-half-dark", "light": "one-half-light"},
        fmt="toml",
    ),
]

AGENT_STATE_FILE = SCRIPT_DIR.parent / "agent_state.json"


def _load_agent_state() -> dict[str, object]:
    if AGENT_STATE_FILE.exists():
        try:
            return json.loads(AGENT_STATE_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {}


def _save_agent_state(state: dict[str, object]) -> None:
    AGENT_STATE_FILE.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")


def _resolve_theme_for_mode(
    state: dict[str, object],
    mode: str,
    current_theme: str | None,
    agent: AgentThemeConfig,
) -> str | None:
    """Determine the correct theme for the given mode and update state."""
    app_memory = state.setdefault(agent.key, {})
    if not isinstance(app_memory, dict):
        raise ValueError(f"invalid agent theme state for {agent.key}")

    last_mode = _normalize_mode(app_memory.get("last_mode"))
    last_applied = _normalize_theme(app_memory.get("last_applied"))
    if not last_mode or not last_applied:
        raise ValueError(f"incomplete agent theme state for {agent.key}")

    if agent.mode_only:
        target_theme = agent.defaults.get(mode, mode)
    else:
        known_mode_themes = {
            theme
            for theme in (
                _normalize_theme(app_memory.get("dark")),
                _normalize_theme(app_memory.get("light")),
                agent.defaults.get("dark"),
                agent.defaults.get("light"),
            )
            if theme
        }
        if (
            last_mode == mode
            and current_theme
            and current_theme != last_applied
            and current_theme not in known_mode_themes
        ):
            app_memory[last_mode] = current_theme

        target_theme = _normalize_theme(app_memory.get(mode))
        if not target_theme:
            target_theme = agent.defaults.get(mode)

    if not target_theme:
        return None

    app_memory[mode] = target_theme
    app_memory["last_mode"] = mode
    app_memory["last_applied"] = target_theme
    return target_theme


def _get_nested(data: dict, path: list[str]) -> str | None:
    """Read a value from a nested dict following a key path."""
    obj = data
    for key in path[:-1]:
        obj = obj.get(key)
        if not isinstance(obj, dict):
            return None
    return _normalize_theme(obj.get(path[-1]))


def _set_nested(data: dict, path: list[str], value: str) -> None:
    """Set a value in a nested dict, creating intermediate dicts as needed."""
    obj = data
    for key in path[:-1]:
        if key not in obj or not isinstance(obj[key], dict):
            obj[key] = {}
        obj = obj[key]
    obj[path[-1]] = value


def _read_agent_theme(agent: AgentThemeConfig, filepath: Path) -> str | None:
    """Read the current theme from a config file (json or toml)."""
    try:
        text = filepath.read_text(encoding="utf-8")
        data = tomllib.loads(text) if agent.fmt == "toml" else json.loads(text)
    except Exception:
        return None
    return _get_nested(data, agent.theme_path)


def _write_toml_theme(filepath: Path, path: list[str], value: str) -> None:
    """Surgically set a single `key = "value"` under a bare ``[section]`` header.

    Only the two-segment ``[section].key`` shape used for agent themes (e.g.
    ``["tui", "theme"]``) is supported; the rest of the TOML is left byte-for-byte
    intact, so unrelated tables (mcp_servers, hooks.state, projects) are untouched.
    """
    section, key = path[0], path[1]
    lines = filepath.read_text(encoding="utf-8").splitlines()
    header = f"[{section}]"
    new_line = f'{key} = "{value}"'
    key_re = re.compile(rf"^\s*{re.escape(key)}\s*=")

    section_idx = next((i for i, ln in enumerate(lines) if ln.strip() == header), None)
    if section_idx is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend([header, new_line])
    else:
        section_end = len(lines)
        for j in range(section_idx + 1, len(lines)):
            if re.match(r"^\s*\[", lines[j]):
                section_end = j
                break
        for j in range(section_idx + 1, section_end):
            if key_re.match(lines[j]):
                lines[j] = new_line
                break
        else:
            lines.insert(section_idx + 1, new_line)
    filepath.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_agent_theme(agent: AgentThemeConfig, filepath: Path, target: str) -> None:
    """Write the resolved theme back to a config file (json or toml)."""
    if agent.fmt == "toml":
        _write_toml_theme(filepath, agent.theme_path, target)
        return
    data = json.loads(filepath.read_text(encoding="utf-8"))
    _set_nested(data, agent.theme_path, target)
    data.pop("_teleclaude_theme_memory", None)
    filepath.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def sync_agent_themes(mode: str, state: dict[str, object]) -> None:
    for agent in AGENTS:
        current_theme: str | None = None
        for filepath in agent.files:
            if not filepath.exists():
                continue
            current_theme = _read_agent_theme(agent, filepath)
            if current_theme:
                break

        target = _resolve_theme_for_mode(state, mode, current_theme, agent)
        if not target:
            continue

        for filepath in agent.files:
            if not filepath.exists():
                continue
            try:
                _write_agent_theme(agent, filepath, target)
                log(f"reload {agent.key} theme synced file={filepath} mode={mode}")
            except Exception as exc:
                log(f"reload {agent.key} theme failed file={filepath} error={exc}")


# ---------------------------------------------------------------------------
# tmux helpers
# ---------------------------------------------------------------------------


def tmux_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["tmux", *args], capture_output=True, text=True)


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------


def cmd_get_mode() -> int:
    print(get_mode())
    return 0


def cmd_get_terminal_bg() -> int:
    bg = get_terminal_bg()
    if not bg:
        return 1
    print(bg)
    return 0


def reload_mode(mode: str) -> int:
    log(f"reload start pid={os.getpid()} mode={mode}")

    state = _load_agent_state()
    sync_agent_themes(mode, state)
    _save_agent_state(state)

    tmux_command(["set", "-g", "@appearance_mode", mode])

    # Notify TeleClaude TUI to refresh colors.
    # The TUI runs as the first pane in the tc_tui tmux session.
    # tmux tracks the pane PID directly — no process name guessing.
    tui_panes = subprocess.run(
        ["tmux", "list-panes", "-t", "tc_tui", "-F", "#{pane_pid}"],
        capture_output=True,
        text=True,
        check=False,
    )
    if tui_panes.returncode == 0:
        pids = tui_panes.stdout.strip().split("\n")
        if pids and pids[0].isdigit():
            subprocess.run(
                ["/bin/kill", "-USR1", pids[0]],
                capture_output=True,
                text=True,
                check=False,
            )

    log("reload complete")
    return 0


def cmd_reload() -> int:
    return reload_mode(get_mode())


def cmd_apply_system() -> int:
    if not is_macos():
        print("apply-system is only supported on macOS.", file=sys.stderr)
        return 1
    mode = get_solar_mode(allow_fallback=False)
    if mode is None:
        print("Solar appearance unavailable; leaving macOS Appearance unchanged.", file=sys.stderr)
        return 1
    if not set_macos_appearance(mode):
        return 1
    return 0


def cmd_watch() -> int:
    if is_macos():
        print("On macOS, use the Swift-based appearance-watcher instead.")
        print("This polling watcher is for Linux fallback only.")

    print("Starting appearance watcher (polling)...")
    last_mode = get_mode()
    while True:
        time.sleep(60)
        current_mode = get_mode()
        if current_mode != last_mode:
            last_mode = current_mode
            cmd_reload()


def cmd_help() -> int:
    help_text = """Usage: appearance <command>

Commands:
  get-mode          Output current mode (dark/light)
  get-terminal-bg   Output terminal background hex color
  reload            Sync agent CLI themes and signal TUI refresh
  apply-system      Set macOS Appearance from sunrise/sunset offset
  watch             Poll for appearance changes (Linux fallback)

Environment variables:
  APPEARANCE_MODE       Override mode detection (dark/light)
  TERMINAL_BG           Override terminal background (#rrggbb)
  APPEARANCE_LATITUDE   Latitude for sunrise-sunset (default: 52.37)
  APPEARANCE_LONGITUDE  Longitude for sunrise-sunset (default: 4.89)
  APPEARANCE_DARK_OFFSET_MINUTES
                        Always start dark mode this many minutes before sunset (default: 0)
  APPEARANCE_DST_DARK_OFFSET_MINUTES
                        Extra dark offset while local DST is active (default: 0)
  APPEARANCE_CACHE_DIR  Cache directory for sunrise-sunset data (default: /tmp)
  APPEARANCE_LOG        Enable logging (default: 1)
"""
    print(help_text)
    return 0


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "help"
    if command == "get-mode":
        return cmd_get_mode()
    if command == "get-terminal-bg":
        return cmd_get_terminal_bg()
    if command == "reload":
        return cmd_reload()
    if command == "apply-system":
        return cmd_apply_system()
    if command == "watch":
        return cmd_watch()
    if command in {"help", "--help", "-h"}:
        return cmd_help()

    print(f"Unknown command: {command}", file=sys.stderr)
    return cmd_help()


if __name__ == "__main__":
    sys.exit(main())
