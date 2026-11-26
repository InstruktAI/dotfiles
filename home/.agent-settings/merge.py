#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "tomlkit>=0.13",
# ]
# ///
"""Merge managed agent CLI defaults into a settings file, keeping every other key.

Reads the current file on stdin and writes the merged file to stdout. The
format (JSON or TOML) follows the defaults file's extension.

    merge.py DEFAULTS [--seed PATH]... [--union PATH]...

Merge rules, applied for each leaf of DEFAULTS:

- A table/object recurses; keys the defaults do not name are never touched.
- A value replaces the current value (lists included: a list is one value).
- ``--seed PATH``: set only when the key is absent, so a machine's own value
  (e.g. a newer model) is kept.
- ``--union PATH``: the list keeps its current entries and gains the missing
  default entries, for lists the CLI itself appends to (permission rules).

PATH is dot-separated (``permissions.allow``). When nothing changes, the input
is written back byte for byte, so a tool's own formatting is never churned.

Strict by design: input that does not parse, a top level that is not a
table/object, or a managed path whose current value has another shape exits
non-zero with a message and writes nothing. The ``modify`` wrapper turns that
into "leave the file as it is".
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, MutableMapping

import tomlkit


class MergeError(Exception):
    pass


def _is_table(value: Any) -> bool:
    return isinstance(value, MutableMapping)


def merge(
    current: MutableMapping[str, Any],
    defaults: dict[str, Any],
    *,
    seed: set[str],
    union: set[str],
    new_table: Any,
    prefix: str = "",
) -> None:
    """Merge ``defaults`` into ``current`` in place."""
    for key, want in defaults.items():
        path = f"{prefix}{key}"
        if isinstance(want, dict):
            if key not in current:
                current[key] = new_table()
            elif not _is_table(current[key]):
                raise MergeError(f"{path} is not a table/object; refusing to replace it")
            merge(current[key], want, seed=seed, union=union, new_table=new_table, prefix=f"{path}.")
        elif path in seed:
            if key not in current:
                current[key] = want
        elif path in union:
            if key not in current:
                current[key] = list(want)
                continue
            have = current[key]
            if not isinstance(have, list):
                raise MergeError(f"{path} is not a list; refusing to replace it")
            for item in want:
                if item not in have:
                    have.append(item)
        else:
            current[key] = want


def _plain(value: Any) -> Any:
    """tomlkit containers -> plain Python values, for comparing documents."""
    return value.unwrap() if hasattr(value, "unwrap") else value


def merge_json(text: str, defaults: dict[str, Any], seed: set[str], union: set[str]) -> str:
    if text.strip():
        try:
            current = json.loads(text)
        except json.JSONDecodeError as exc:
            raise MergeError(f"not valid JSON ({exc})") from exc
        if not isinstance(current, dict):
            raise MergeError("top level is not a JSON object")
    else:
        current = {}
    before = json.loads(json.dumps(current))
    merge(current, defaults, seed=seed, union=union, new_table=dict)
    if text.strip() and current == before:
        return text
    return json.dumps(current, indent=2, ensure_ascii=False) + "\n"


def merge_toml(text: str, defaults: dict[str, Any], seed: set[str], union: set[str]) -> str:
    try:
        current = tomlkit.parse(text)
    except tomlkit.exceptions.TOMLKitError as exc:
        raise MergeError(f"not valid TOML ({exc})") from exc
    before = _plain(current)
    merge(current, defaults, seed=seed, union=union, new_table=tomlkit.table)
    if text.strip() and _plain(current) == before:
        return text
    out = tomlkit.dumps(current)
    # Reject our own output if it would not read back: never emit broken TOML.
    tomlkit.parse(out)
    return out


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("defaults", type=Path)
    parser.add_argument("--seed", action="append", default=[], metavar="PATH")
    parser.add_argument("--union", action="append", default=[], metavar="PATH")
    args = parser.parse_args(argv)

    suffix = args.defaults.suffix
    raw = args.defaults.read_text(encoding="utf-8")
    text = sys.stdin.read()
    try:
        if suffix == ".json":
            out = merge_json(text, json.loads(raw), set(args.seed), set(args.union))
        elif suffix == ".toml":
            out = merge_toml(text, tomlkit.parse(raw).unwrap(), set(args.seed), set(args.union))
        else:
            raise MergeError(f"unsupported defaults format: {args.defaults.name}")
    except MergeError as exc:
        print(f"agent-settings: {exc}", file=sys.stderr)
        return 1
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
