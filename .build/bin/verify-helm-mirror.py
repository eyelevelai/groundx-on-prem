#!/usr/bin/env python3
"""Verify src/groundx/templates and helm/templates stay byte-for-byte mirrored."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SRC_TEMPLATES = ROOT / "src" / "groundx" / "templates"
MIRROR_TEMPLATES = ROOT / "helm" / "templates"


def compare_trees(src: Path, mirror: Path) -> list[str]:
    failures: list[str] = []

    src_files = {p.relative_to(src): p for p in src.rglob("*") if p.is_file()}
    mirror_files = {p.relative_to(mirror): p for p in mirror.rglob("*") if p.is_file()}

    for rel in sorted(set(src_files) | set(mirror_files)):
        in_src = rel in src_files
        in_mirror = rel in mirror_files

        if in_src and not in_mirror:
            failures.append(f"{rel.as_posix()} present only under {src} (missing from {mirror})")
            continue
        if in_mirror and not in_src:
            failures.append(f"{rel.as_posix()} present only under {mirror} (missing from {src})")
            continue

        try:
            src_bytes = src_files[rel].read_bytes()
            mirror_bytes = mirror_files[rel].read_bytes()
        except OSError as exc:
            failures.append(f"{rel.as_posix()}: failed to read for comparison: {exc}")
            continue

        if src_bytes != mirror_bytes:
            failures.append(f"{rel.as_posix()} content differs between {src} and {mirror}")

    return failures


def main() -> int:
    if not SRC_TEMPLATES.is_dir():
        print(f"verify-helm-mirror: missing source template tree: {SRC_TEMPLATES}", file=sys.stderr)
        return 1
    if not MIRROR_TEMPLATES.is_dir():
        print(f"verify-helm-mirror: missing mirror template tree: {MIRROR_TEMPLATES}", file=sys.stderr)
        return 1

    failures = compare_trees(SRC_TEMPLATES, MIRROR_TEMPLATES)

    if failures:
        print(
            f"Helm template mirror verification failed: {SRC_TEMPLATES.relative_to(ROOT)} "
            f"and {MIRROR_TEMPLATES.relative_to(ROOT)} are out of sync.",
            file=sys.stderr,
        )
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(
        f"{SRC_TEMPLATES.relative_to(ROOT)} and {MIRROR_TEMPLATES.relative_to(ROOT)} match byte-for-byte."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
