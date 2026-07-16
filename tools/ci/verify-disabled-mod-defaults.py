#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ASSIGNMENT = re.compile(
    r"^\s*([^:;][^:]*)\s*:\s*([01])\s*$"
)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_json(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {path}: {error}")

    if not isinstance(data, list) or not data:
        fail(f"{path} must contain a nonempty JSON list")

    names: list[str] = []
    seen: set[str] = set()

    for index, entry in enumerate(data):
        if not isinstance(entry, dict):
            fail(f"{path}: entry {index} is not an object")

        name = entry.get("mod_name")
        enabled = entry.get("mod_enabled")

        if not isinstance(name, str) or not name.strip():
            fail(f"{path}: entry {index} has an invalid mod_name")

        name = name.strip()

        if name in seen:
            fail(f"{path}: duplicate mod name: {name}")

        if enabled is not False:
            fail(f"{path}: bundled mod is enabled: {name}")

        seen.add(name)
        names.append(name)

    return names


def read_text(path: Path) -> list[str]:
    try:
        lines = path.read_text().splitlines()
    except OSError as error:
        fail(f"cannot read {path}: {error}")

    names: list[str] = []
    seen: set[str] = set()

    for line_number, line in enumerate(lines, start=1):
        stripped = line.strip()

        if not stripped or stripped.startswith(";"):
            continue

        match = ASSIGNMENT.fullmatch(line)

        if match is None:
            fail(
                f"{path}:{line_number}: invalid mod assignment: "
                f"{line!r}"
            )

        name = match.group(1).strip()
        enabled = match.group(2)

        if name in seen:
            fail(f"{path}: duplicate mod name: {name}")

        if enabled != "0":
            fail(f"{path}: bundled mod is enabled: {name}")

        seen.add(name)
        names.append(name)

    if not names:
        fail(f"{path} contains no mod assignments")

    return names


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify that all bundled UE4SS mods default to disabled."
    )
    parser.add_argument("mods_json", type=Path)
    parser.add_argument("mods_txt", type=Path)
    args = parser.parse_args()

    json_names = read_json(args.mods_json)
    text_names = read_text(args.mods_txt)

    if json_names != text_names:
        fail(
            "mods.json and mods.txt do not declare the same mods "
            "in the same order"
        )

    print(f"DisabledModDefaults={len(json_names)}")
    print("RESULT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
