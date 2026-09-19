#!/usr/bin/env python3
"""Verify the installed helm-unittest plugin version matches the repo's pin."""

from __future__ import annotations

import os
import re
import shlex
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PIN_FILE = ROOT / ".build" / "HELM_UNITTEST_VERSION"
FALLBACK_PLUGINS_DIR = Path.home() / ".local" / "share" / "helm" / "plugins"
PLUGIN_NAME = "unittest"

_NAME_PATTERN = re.compile(r'^name:\s*"?([^"\n]+?)"?\s*$', re.MULTILINE)
_VERSION_PATTERN = re.compile(r'^version:\s*"?([^"\n]+?)"?\s*$', re.MULTILINE)


def pinned_version(pin_file: Path) -> str:
    return pin_file.read_text(encoding="utf-8").strip()


def _read_field(plugin_yaml: Path, pattern: re.Pattern[str]) -> str | None:
    text = plugin_yaml.read_text(encoding="utf-8")
    match = pattern.search(text)
    return match.group(1).strip() if match else None


def installed_version(plugins_dir: Path) -> str | None:
    if not plugins_dir.is_dir():
        return None

    for plugin_yaml in sorted(plugins_dir.glob("*/plugin.yaml")):
        name = _read_field(plugin_yaml, _NAME_PATTERN)
        if name != PLUGIN_NAME:
            continue
        return _read_field(plugin_yaml, _VERSION_PATTERN)

    return None


def normalize(version: str) -> str:
    return version.strip().lstrip("vV")


def resolve_plugins_dir() -> Path:
    helm_bin = os.environ.get("HELM_BIN", "helm")
    try:
        result = subprocess.run(
            shlex.split(helm_bin, posix=(os.name != "nt")) + ["env", "HELM_PLUGINS"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return FALLBACK_PLUGINS_DIR

    resolved = result.stdout.strip()
    if result.returncode == 0 and resolved:
        return Path(resolved)
    return FALLBACK_PLUGINS_DIR


def main() -> int:
    if not PIN_FILE.is_file():
        print(f"verify-helm-unittest-plugin-version: missing pin file: {PIN_FILE}", file=sys.stderr)
        return 1

    try:
        pinned = pinned_version(PIN_FILE)
    except OSError as exc:
        print(f"verify-helm-unittest-plugin-version: failed to read pin file {PIN_FILE}: {exc}", file=sys.stderr)
        return 1

    if not pinned:
        print(f"verify-helm-unittest-plugin-version: pin file is empty: {PIN_FILE}", file=sys.stderr)
        return 1

    plugins_dir = resolve_plugins_dir()

    try:
        installed = installed_version(plugins_dir)
    except OSError as exc:
        print(
            f"verify-helm-unittest-plugin-version: failed to read installed plugin.yaml under {plugins_dir}: {exc}",
            file=sys.stderr,
        )
        return 1

    if installed is None:
        print(
            f"verify-helm-unittest-plugin-version: helm-unittest plugin not found under {plugins_dir} "
            f"(expected a plugin.yaml naming '{PLUGIN_NAME}')",
            file=sys.stderr,
        )
        return 1

    if normalize(installed) != normalize(pinned):
        print(
            "verify-helm-unittest-plugin-version: installed helm-unittest plugin version "
            f"'{installed}' does not match the pin '{pinned}' ({PIN_FILE})",
            file=sys.stderr,
        )
        return 1

    print(f"verify-helm-unittest-plugin-version: installed helm-unittest plugin matches pin ({pinned}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
