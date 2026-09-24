#!/usr/bin/env python3
"""Verify the installed helm-unittest plugin version matches the repo's pin."""

from __future__ import annotations

import hashlib
import os
import platform
import re
import shlex
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PIN_FILE = ROOT / ".build" / "HELM_UNITTEST_VERSION"
REFERENCE_HASH_FILE = ROOT / ".build" / "HELM_UNITTEST_BINARY_SHA256"
FALLBACK_PLUGINS_DIR = Path.home() / ".local" / "share" / "helm" / "plugins"
PLUGIN_NAME = "unittest"

_NAME_PATTERN = re.compile(r'^name:\s*"?([^"\n]+?)"?\s*$', re.MULTILINE)
_VERSION_PATTERN = re.compile(r'^version:\s*"?([^"\n]+?)"?\s*$', re.MULTILINE)


class BinaryVerificationError(Exception):
    pass


def pinned_version(pin_file: Path) -> str:
    return pin_file.read_text(encoding="utf-8").strip()


def _read_field(plugin_yaml: Path, pattern: re.Pattern[str]) -> str | None:
    text = plugin_yaml.read_text(encoding="utf-8")
    match = pattern.search(text)
    return match.group(1).strip() if match else None


def find_plugin_dir(plugins_dir: Path) -> Path | None:
    if not plugins_dir.is_dir():
        return None

    for plugin_yaml in sorted(plugins_dir.glob("*/plugin.yaml")):
        name = _read_field(plugin_yaml, _NAME_PATTERN)
        if name != PLUGIN_NAME:
            continue
        return plugin_yaml.parent

    return None


def installed_version(plugins_dir: Path) -> str | None:
    plugin_dir = find_plugin_dir(plugins_dir)
    if plugin_dir is None:
        return None
    return _read_field(plugin_dir / "plugin.yaml", _VERSION_PATTERN)


def normalize(version: str) -> str:
    return version.strip().lstrip("vV")


def resolve_os() -> str:
    system = platform.system().strip().lower()
    if system in ("windows", "windows_nt") or system.startswith(("mingw", "msys")):
        return "windows"
    if system == "darwin":
        return "macos"
    return system


def resolve_arch() -> str:
    machine = platform.machine().strip().lower()
    if machine.startswith("armv5"):
        return "armv5"
    if machine.startswith("armv6"):
        return "armv6"
    if machine.startswith("armv7"):
        return "armv7"
    if machine in ("aarch64", "arm64"):
        return "arm64"
    if machine in ("x86", "i686", "i386"):
        return "386"
    if machine in ("x86_64", "amd64"):
        return "amd64"
    if machine in ("ppc64le", "s390x"):
        return machine
    return machine


def binary_file_name(os_name: str, arch: str) -> str:
    suffix = ".exe" if os_name == "windows" else ""
    return f"untt-{os_name}-{arch}{suffix}"


def read_reference_hashes(reference_file: Path) -> dict[str, str]:
    hashes: dict[str, str] = {}
    for line in reference_file.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = stripped.split()
        if len(parts) != 2:
            raise BinaryVerificationError(
                f"malformed line in reference hash file {reference_file}: '{line}'"
            )
        platform_key, digest = parts
        hashes[platform_key] = digest.lower()
    return hashes


def verify_binary_integrity(plugin_dir: Path, os_name: str, arch: str, reference_file: Path) -> None:
    member_name = binary_file_name(os_name, arch)
    binary_path = plugin_dir / member_name

    if not binary_path.is_file():
        raise BinaryVerificationError(f"installed helm-unittest binary not found at {binary_path}")

    try:
        installed_bytes = binary_path.read_bytes()
    except OSError as exc:
        raise BinaryVerificationError(
            f"failed to read installed helm-unittest binary at {binary_path}: {exc}"
        ) from exc

    if not reference_file.is_file():
        raise BinaryVerificationError(f"missing reference hash file: {reference_file}")

    try:
        reference_hashes = read_reference_hashes(reference_file)
    except OSError as exc:
        raise BinaryVerificationError(
            f"failed to read reference hash file {reference_file}: {exc}"
        ) from exc

    platform_key = f"{os_name}-{arch}"
    pinned_hash = reference_hashes.get(platform_key)
    if pinned_hash is None:
        raise BinaryVerificationError(
            f"no reference sha256 entry for platform '{platform_key}' in {reference_file}"
        )

    installed_hash = hashlib.sha256(installed_bytes).hexdigest()

    if installed_hash != pinned_hash:
        raise BinaryVerificationError(
            f"installed helm-unittest binary at {binary_path} does not match the reference sha256 "
            f"for {platform_key}: installed sha256={installed_hash}, pinned sha256={pinned_hash}"
        )


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

    plugin_dir = find_plugin_dir(plugins_dir)
    if plugin_dir is None:
        print(
            f"verify-helm-unittest-plugin-version: helm-unittest plugin not found under {plugins_dir} "
            f"(expected a plugin.yaml naming '{PLUGIN_NAME}') while resolving the binary path",
            file=sys.stderr,
        )
        return 1

    os_name = resolve_os()
    arch = resolve_arch()

    try:
        verify_binary_integrity(plugin_dir, os_name, arch, REFERENCE_HASH_FILE)
    except BinaryVerificationError as exc:
        print(f"verify-helm-unittest-plugin-version: {exc}", file=sys.stderr)
        return 1

    print(
        f"verify-helm-unittest-plugin-version: installed helm-unittest plugin matches pin ({pinned}), "
        f"binary verified against the pinned release for {os_name}-{arch}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
