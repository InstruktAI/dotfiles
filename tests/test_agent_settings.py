#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# ///
"""Tests for the agent CLI settings modify_ scripts (home/.agent-settings).

Every test works in a temporary HOME; the real one is never read or written.
The modify_ scripts run exactly as chezmoi runs them (current file on stdin,
CHEZMOI_SOURCE_DIR set), and the end-to-end tests run `chezmoi apply` and
`chezmoi verify` against this checkout with HOME pointing at a temp dir.

    uv run --script tests/test_agent_settings.py      # or: make test
"""

from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import tempfile
import textwrap
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "home"
CLAUDE = "dot_claude/modify_settings.json"
CODEX = "dot_codex/modify_private_config.toml"
AGY = "dot_gemini/antigravity-cli/modify_private_settings.json"
TARGETS = {
    CLAUDE: ".claude/settings.json",
    CODEX: ".codex/config.toml",
    AGY: ".gemini/antigravity-cli/settings.json",
}

CLAUDE_LIVE = json.dumps(
    {
        "$schema": "https://json.schemastore.org/claude-code-settings.json",
        "cleanupPeriodDays": 99999,
        "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1", "MY_OWN_VAR": "x"},
        "permissions": {"allow": ["Bash(ls:*)"], "deny": [], "defaultMode": "default"},
        "model": "opus[1m]",
        "hooks": {},
        "statusLine": {"type": "command", "command": "bunx -y ccstatusline@latest", "padding": 0},
        "enabledPlugins": {"hookify@claude-plugins-official": True},
        "pluginConfigs": {
            "agents-md@builtin": {"options": {"instructionFiles": "claude-md-and-agents-md"}}
        },
        "theme": "light",
        "feedbackSurveyState": {"lastShownTime": 1754048693214},
        "note": "a & b <c> ü",
    },
    indent=2,
    ensure_ascii=False,
) + "\n"

CODEX_LIVE = textwrap.dedent(
    """\
    # my own comment stays
    approval_policy = "on-request"
    model = "gpt-6.1-terra"
    notify = ["notifier", "--codex"]
    project_root_markers = [".git"]

    [tui]
    theme = "one-half-dark"
      auto_recap = true

    [tui.model_availability_nux]
      "gpt-6.1-sol" = 4

    [hooks.state."/work/.codex/hooks.json:stop:0:0"]
      trusted_hash = "sha256:abc"

    [projects."/work/project-a"]
      trust_level = "trusted"
    """
)

AGY_LIVE = json.dumps(
    {
        "allowNonWorkspaceAccess": False,
        "colorScheme": "dark",
        "context": {"fileName": ["AGENTS.md"]},
        "general": {"sessionRetention": {"enabled": True, "maxAge": "1460d"}},
        "model": "some-model",
        "permissions": {"allow": ["command(git status)", "read_file(*)"]},
        "trustedWorkspaces": ["/work/project-a"],
    },
    indent=2,
)


def _env(home: Path, **extra: str) -> dict[str, str]:
    env = dict(os.environ)
    env.update(HOME=str(home), CHEZMOI_SOURCE_DIR=str(SOURCE), XDG_CONFIG_HOME=str(home / ".config"))
    env.update(extra)
    return env


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self.home = Path(tempfile.mkdtemp(prefix="agent-settings-test-"))
        self.addCleanup(shutil.rmtree, self.home, ignore_errors=True)

    def modify(self, script: str, current: str, **env: str) -> subprocess.CompletedProcess[str]:
        """Run a modify_ script the way chezmoi does."""
        return subprocess.run(
            ["bash", str(SOURCE / script)],
            input=current,
            capture_output=True,
            text=True,
            env=_env(self.home, **env),
            check=True,
        )


class ClaudeTest(Base):
    def test_sets_managed_keys_and_keeps_the_rest(self) -> None:
        out = json.loads(self.modify(CLAUDE, CLAUDE_LIVE).stdout)
        live = json.loads(CLAUDE_LIVE)
        # Owned elsewhere: untouched.
        self.assertEqual(out["pluginConfigs"], live["pluginConfigs"])  # instrukt
        self.assertEqual(out["theme"], "light")  # appearance
        self.assertEqual(out["model"], "opus[1m]")
        # Dropped from management, not removed from the machine.
        self.assertEqual(out["cleanupPeriodDays"], 99999)
        self.assertEqual(out["hooks"], {})
        # Managed keys set; siblings in the same objects kept.
        self.assertEqual(out["effortLevel"], "xhigh")
        self.assertEqual(out["statusLine"]["command"], "bunx -y ccstatusline@2.2.32")
        self.assertEqual(out["permissions"], {"allow": ["Bash(ls:*)"], "deny": [], "defaultMode": "bypassPermissions"})
        self.assertEqual(out["env"]["MY_OWN_VAR"], "x")
        self.assertEqual(out["env"]["CLAUDE_CODE_DISABLE_AUTO_MEMORY"], "1")
        self.assertTrue(out["enabledPlugins"]["hookify@claude-plugins-official"])
        self.assertTrue(out["enabledPlugins"]["pyright-lsp@claude-plugins-official"])
        # Values survive exactly: big integers, non-ASCII, key order.
        self.assertEqual(out["feedbackSurveyState"]["lastShownTime"], 1754048693214)
        self.assertEqual(out["note"], "a & b <c> ü")
        self.assertEqual(list(out)[:3], ["$schema", "cleanupPeriodDays", "env"])
        self.assertNotIn("PreToolUse", out["hooks"])

    def test_idempotent(self) -> None:
        once = self.modify(CLAUDE, CLAUDE_LIVE).stdout
        self.assertEqual(self.modify(CLAUDE, once).stdout, once)

    def test_converged_file_comes_back_byte_for_byte(self) -> None:
        merged = json.loads(self.modify(CLAUDE, CLAUDE_LIVE).stdout)
        own_format = json.dumps(merged, indent=4)  # not the format merge.py writes
        self.assertEqual(self.modify(CLAUDE, own_format).stdout, own_format)

    def test_absent_file_gets_the_defaults(self) -> None:
        out = json.loads(self.modify(CLAUDE, "").stdout)
        self.assertEqual(out, json.loads((SOURCE / ".agent-settings/claude.json").read_text()))

    def test_malformed_file_is_left_unchanged(self) -> None:
        broken = '{"theme": "dark",, }\n'
        result = self.modify(CLAUDE, broken)
        self.assertEqual(result.stdout, broken)
        self.assertIn("not valid JSON", result.stderr)

    def test_non_object_top_level_is_left_unchanged(self) -> None:
        self.assertEqual(self.modify(CLAUDE, "[1, 2]\n").stdout, "[1, 2]\n")

    def test_conflicting_shape_is_left_unchanged(self) -> None:
        odd = json.dumps({"env": "not-an-object", "theme": "dark"})
        result = self.modify(CLAUDE, odd)
        self.assertEqual(result.stdout, odd)
        self.assertIn("env is not a table/object", result.stderr)


class CodexTest(Base):
    def test_sets_managed_keys_and_keeps_the_rest(self) -> None:
        text = self.modify(CODEX, CODEX_LIVE).stdout
        out = tomllib.loads(text)
        # Owned elsewhere or machine-local: untouched.
        self.assertEqual(out["model"], "gpt-6.1-terra")  # seeded only
        self.assertEqual(out["tui"]["theme"], "one-half-dark")  # appearance
        self.assertEqual(out["tui"]["model_availability_nux"], {"gpt-6.1-sol": 4})
        self.assertEqual(out["projects"], {"/work/project-a": {"trust_level": "trusted"}})
        self.assertEqual(out["hooks"]["state"]["/work/.codex/hooks.json:stop:0:0"]["trusted_hash"], "sha256:abc")
        self.assertEqual(out["notify"], ["notifier", "--codex"])
        self.assertIn("# my own comment stays", text)
        # Managed keys set, at the top level and in tables.
        self.assertEqual(out["approval_policy"], "never")
        self.assertEqual(out["project_doc_max_bytes"], 262144)
        self.assertEqual(out["project_root_markers"], [])
        self.assertFalse(out["tui"]["auto_recap"])
        self.assertEqual(out["features"]["multi_agent"], True)
        self.assertEqual(out["notice"]["hide_rate_limit_model_nudge"], True)
        # Dropped by the owner: never written.
        self.assertNotIn("experimental_compact_prompt_file", out)

    def test_model_is_seeded_when_absent(self) -> None:
        out = tomllib.loads(self.modify(CODEX, 'approval_policy = "never"\n').stdout)
        self.assertEqual(out["model"], "gpt-6-astra")

    def test_subtable_without_its_parent_header(self) -> None:
        live = '[tui.model_availability_nux]\n"gpt-6.1-sol" = 4\n'
        out = tomllib.loads(self.modify(CODEX, live).stdout)
        self.assertEqual(out["tui"]["model_availability_nux"], {"gpt-6.1-sol": 4})
        self.assertEqual(out["tui"]["session_picker_view"], "comfortable")

    def test_idempotent(self) -> None:
        once = self.modify(CODEX, CODEX_LIVE).stdout
        self.assertEqual(self.modify(CODEX, once).stdout, once)

    def test_absent_file_gets_the_defaults(self) -> None:
        out = tomllib.loads(self.modify(CODEX, "").stdout)
        self.assertEqual(out, tomllib.loads((SOURCE / ".agent-settings/codex.toml").read_text()))

    def test_malformed_file_is_left_unchanged(self) -> None:
        broken = '[tui\ntheme = "one-half-dark"\n'
        result = self.modify(CODEX, broken)
        self.assertEqual(result.stdout, broken)
        self.assertIn("not valid TOML", result.stderr)


class AntigravityTest(Base):
    def test_sets_managed_keys_and_keeps_the_rest(self) -> None:
        out = json.loads(self.modify(AGY, AGY_LIVE).stdout)
        live = json.loads(AGY_LIVE)
        for key in ("colorScheme", "context", "general", "model", "trustedWorkspaces"):
            self.assertEqual(out[key], live[key], key)
        self.assertTrue(out["allowNonWorkspaceAccess"])
        self.assertEqual(out["verbosity"], "high")
        # The rules agy added stay first; the managed ones are appended once.
        allow = out["permissions"]["allow"]
        self.assertEqual(allow[:2], ["command(git status)", "read_file(*)"])
        self.assertEqual(allow.count("read_file(*)"), 1)
        self.assertIn("mcp(*)", allow)
        # Values equal to agy's defaults are not managed (agy strips them).
        self.assertNotIn("enableTerminalSandbox", out)
        self.assertNotIn("statusLine", out)

    def test_idempotent(self) -> None:
        once = self.modify(AGY, AGY_LIVE).stdout
        self.assertEqual(self.modify(AGY, once).stdout, once)

    def test_malformed_file_is_left_unchanged(self) -> None:
        broken = '{"colorScheme": "dark"'
        self.assertEqual(self.modify(AGY, broken).stdout, broken)


class GuardTest(Base):
    """The wrapper never lets a failed merge reach the file."""

    def fake_uv(self, body: str) -> dict[str, str]:
        bin_dir = self.home / "fake-bin"
        bin_dir.mkdir()
        uv = bin_dir / "uv"
        uv.write_text(f"#!/bin/bash\n{body}\n")
        uv.chmod(0o755)
        return {"PATH": f"{bin_dir}:{os.environ['PATH']}"}

    def test_crash_after_partial_output(self) -> None:
        env = self.fake_uv('cat >/dev/null; echo "{"; exit 1')
        result = self.modify(CLAUDE, CLAUDE_LIVE, **env)
        self.assertEqual(result.stdout, CLAUDE_LIVE)
        self.assertIn("left unchanged", result.stderr)

    def test_success_with_empty_output(self) -> None:
        # Empty output would make chezmoi delete the target.
        env = self.fake_uv("cat >/dev/null; exit 0")
        self.assertEqual(self.modify(CODEX, CODEX_LIVE, **env).stdout, CODEX_LIVE)


@unittest.skipUnless(shutil.which("chezmoi"), "chezmoi not installed")
class ChezmoiEndToEndTest(Base):
    def chezmoi(self, *args: str) -> subprocess.CompletedProcess[str]:
        state = self.home / ".chezmoi-test"
        state.mkdir(exist_ok=True)
        env = _env(self.home)
        env.pop("CHEZMOI_SOURCE_DIR")  # chezmoi sets it itself
        return subprocess.run(
            [
                "chezmoi",
                "--no-tty",
                "--config", str(state / "chezmoi.toml"),
                "--persistent-state", str(state / "state.boltdb"),
                "--source", str(SOURCE),
                *args,
                # The managed directories, so chezmoi creates them as a full apply does.
                *(str(self.home / d) for d in (".claude", ".codex", ".gemini")),
            ],
            capture_output=True,
            text=True,
            env=env,
        )

    def write(self, rel: str, text: str) -> Path:
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def snapshot(self) -> dict[str, bytes]:
        return {t: (self.home / t).read_bytes() for t in TARGETS.values()}

    def test_fresh_machine(self) -> None:
        result = self.chezmoi("apply", "--force")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.home / TARGETS[CLAUDE]).read_text())["tui"], "fullscreen")
        self.assertEqual(stat.S_IMODE((self.home / TARGETS[CLAUDE]).stat().st_mode), 0o644)
        self.assertEqual(stat.S_IMODE((self.home / TARGETS[CODEX]).stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE((self.home / TARGETS[AGY]).stat().st_mode), 0o600)
        self.assertEqual(self.chezmoi("verify").returncode, 0)

    def test_existing_files_converge_and_stay_put(self) -> None:
        self.write(TARGETS[CLAUDE], CLAUDE_LIVE)
        self.write(TARGETS[CODEX], CODEX_LIVE)
        self.write(TARGETS[AGY], AGY_LIVE)
        self.assertEqual(self.chezmoi("apply", "--force").returncode, 0)
        first = self.snapshot()
        verify = self.chezmoi("verify")
        self.assertEqual(verify.returncode, 0, verify.stdout + verify.stderr)
        self.assertEqual(self.chezmoi("apply", "--force").returncode, 0)
        self.assertEqual(self.snapshot(), first)
        self.assertEqual(tomllib.loads(first[TARGETS[CODEX]].decode())["tui"]["theme"], "one-half-dark")
        self.assertEqual(json.loads(first[TARGETS[AGY]])["colorScheme"], "dark")

    def test_malformed_file_survives_and_the_rest_still_applies(self) -> None:
        broken = '{"theme": "dark",, }\n'
        self.write(TARGETS[CLAUDE], broken)
        result = self.chezmoi("apply", "--force")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / TARGETS[CLAUDE]).read_text(), broken)
        self.assertIn("not valid JSON", result.stderr)
        self.assertEqual(tomllib.loads((self.home / TARGETS[CODEX]).read_text())["model"], "gpt-6-astra")


if __name__ == "__main__":
    unittest.main(verbosity=2)
