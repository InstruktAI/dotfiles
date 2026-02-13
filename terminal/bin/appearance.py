#!/usr/bin/env python3
"""Unified appearance management - OS agnostic.
Subcommands: get-mode, get-terminal-bg, reload, watch
"""

from __future__ import annotations

import datetime
import json
import os
import plistlib
import subprocess
import sys
import time
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional

SCRIPT_DIR = Path(__file__).resolve().parent

APPEARANCE_LATITUDE = os.environ.get("APPEARANCE_LATITUDE", "52.37")
APPEARANCE_LONGITUDE = os.environ.get("APPEARANCE_LONGITUDE", "4.89")
APPEARANCE_LOG = os.environ.get("APPEARANCE_LOG", "1")
APPEARANCE_LOG_FILE = os.environ.get(
    "APPEARANCE_LOG_FILE", str(SCRIPT_DIR / "appearance.log")
)

DEFAULT_PATH_PREFIX = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
os.environ["PATH"] = f"{DEFAULT_PATH_PREFIX}:{os.environ.get('PATH', '')}"


def log(message: str) -> None:
    if APPEARANCE_LOG != "1":
        return
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(APPEARANCE_LOG_FILE, "a", encoding="utf-8") as handle:
            handle.write(f"{ts} {message}\n")
    except OSError:
        pass


def is_macos() -> bool:
    return sys.platform == "darwin"


def run_command(
    args: list[str], check: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, capture_output=True, text=True)


def is_daylight() -> bool:
    cache_file = Path("/tmp/sunrise-sunset-cache.json")
    cache_max_age = 86400

    def parse_time(value: str) -> Optional[datetime.time]:
        try:
            dt = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
            return dt.time()
        except ValueError:
            try:
                time_part = value.split("T", 1)[1].split("+", 1)[0]
                return datetime.time.fromisoformat(time_part)
            except Exception:
                return None

    def is_now_between(sunrise: str, sunset: str) -> bool:
        sunrise_time = parse_time(sunrise)
        sunset_time = parse_time(sunset)
        if sunrise_time is None or sunset_time is None:
            return False
        now_time = datetime.datetime.utcnow().time()
        return sunrise_time < now_time < sunset_time

    if cache_file.exists():
        age = int(time.time() - cache_file.stat().st_mtime)
        if age < cache_max_age:
            try:
                data = json.loads(cache_file.read_text(encoding="utf-8"))
                results = data.get("results", {})
                sunrise = results.get("sunrise")
                sunset = results.get("sunset")
                if sunrise and sunset:
                    return is_now_between(sunrise, sunset)
            except Exception:
                pass

    url = (
        "https://api.sunrise-sunset.org/json"
        f"?lat={APPEARANCE_LATITUDE}&lng={APPEARANCE_LONGITUDE}&formatted=0"
    )
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            payload = response.read().decode("utf-8")
        data = json.loads(payload)
        if data.get("status") == "OK":
            cache_file.write_text(json.dumps(data), encoding="utf-8")
            results = data.get("results", {})
            sunrise = results.get("sunrise")
            sunset = results.get("sunset")
            if sunrise and sunset:
                return is_now_between(sunrise, sunset)
    except Exception:
        pass

    hour = datetime.datetime.now().hour
    return 6 <= hour < 18


def get_mode() -> str:
    env_mode = os.environ.get("APPEARANCE_MODE")
    if env_mode:
        log(f"get_mode using APPEARANCE_MODE={env_mode}")
        return env_mode

    if is_macos():
        try:
            result = run_command(["defaults", "read", "-g", "AppleInterfaceStyle"])
            if result.returncode == 0 and "Dark" in result.stdout:
                log("get_mode detected dark from macOS defaults")
                return "dark"
        except Exception:
            pass
        log("get_mode detected light from macOS defaults")
        return "light"

    if is_daylight():
        log("get_mode detected light from sunrise-sunset")
        return "light"

    log("get_mode detected dark from sunrise-sunset")
    return "dark"


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


AGENTS: list[AgentThemeConfig] = [
    AgentThemeConfig(
        key="claude",
        files=[Path.home() / ".claude" / "settings.json", Path.home() / ".claude.json"],
        theme_path=["theme"],
        defaults={"dark": "dark", "light": "light"},
    ),
    AgentThemeConfig(
        key="gemini",
        files=[Path.home() / ".gemini" / "settings.json"],
        theme_path=["ui", "theme"],
        defaults={"dark": "Default", "light": "Default Light"},
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
    app_key: str,
    app_defaults: dict[str, str],
) -> str | None:
    """Determine the correct theme for the given mode and update state."""
    app_memory = state.setdefault(app_key, {})

    last_mode = _normalize_mode(app_memory.get("last_mode"))
    remembered_dark = _normalize_theme(app_memory.get("dark"))
    remembered_light = _normalize_theme(app_memory.get("light"))

    target_theme: str | None = None

    if last_mode == mode:
        if current_theme:
            app_memory[mode] = current_theme
    else:
        if last_mode and current_theme:
            app_memory[last_mode] = current_theme

        target_theme = remembered_dark if mode == "dark" else remembered_light
        if not target_theme:
            target_theme = app_defaults.get(mode)
        if target_theme:
            app_memory[mode] = target_theme

    app_memory["last_mode"] = mode
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


def sync_agent_themes(mode: str, state: dict[str, object]) -> None:
    for agent in AGENTS:
        current_theme: str | None = None
        for filepath in agent.files:
            if not filepath.exists():
                continue
            try:
                data = json.loads(filepath.read_text(encoding="utf-8"))
                current_theme = _get_nested(data, agent.theme_path)
                if current_theme:
                    break
            except Exception:
                pass

        target = _resolve_theme_for_mode(
            state, mode, current_theme, agent.key, agent.defaults
        )

        for filepath in agent.files:
            if not filepath.exists():
                continue
            try:
                data = json.loads(filepath.read_text(encoding="utf-8"))
                if target:
                    _set_nested(data, agent.theme_path, target)
                data.pop("_teleclaude_theme_memory", None)
                filepath.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
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


def cmd_reload() -> int:
    mode = get_mode()
    log(f"reload start pid={os.getpid()} mode={mode}")

    state = _load_agent_state()
    sync_agent_themes(mode, state)
    _save_agent_state(state)

    tmux_command(["set", "-g", "@appearance_mode", mode])

    # Notify TeleClaude TUI to refresh colors.
    pgrep = subprocess.run(
        ["/usr/bin/pgrep", "-f", "teleclaude.cli.telec"],
        capture_output=True,
        text=True,
        check=False,
    )
    pids = [pid for pid in pgrep.stdout.split() if pid.isdigit()]
    for pid in pids:
        subprocess.run(
            ["/bin/kill", "-USR1", pid],
            capture_output=True,
            text=True,
            check=False,
        )

    log("reload complete")
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
  watch             Poll for appearance changes (Linux fallback)

Environment variables:
  APPEARANCE_MODE       Override mode detection (dark/light)
  TERMINAL_BG           Override terminal background (#rrggbb)
  APPEARANCE_LATITUDE   Latitude for sunrise-sunset (default: 52.37)
  APPEARANCE_LONGITUDE  Longitude for sunrise-sunset (default: 4.89)
  APPEARANCE_LOG        Enable logging (default: 1)
  APPEARANCE_LOG_FILE   Log file path
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
    if command == "watch":
        return cmd_watch()
    if command in {"help", "--help", "-h"}:
        return cmd_help()

    print(f"Unknown command: {command}", file=sys.stderr)
    return cmd_help()


if __name__ == "__main__":
    sys.exit(main())
