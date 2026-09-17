#!/usr/bin/env python3
"""Assert helm unittest does not rewrite committed snapshots as a side effect of running."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_DIR = ROOT / "src" / "groundx" / "tests" / "__snapshot__"


def compute_hashes(snapshot_dir: Path) -> dict[str, str]:
    hashes: dict[str, str] = {}
    if not snapshot_dir.is_dir():
        return hashes

    for path in sorted(snapshot_dir.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(snapshot_dir).as_posix()
        hashes[rel] = hashlib.sha256(path.read_bytes()).hexdigest()

    return hashes


def serialize_hashes(hashes: dict[str, str]) -> str:
    lines = [f"{rel}\t{digest}" for rel, digest in sorted(hashes.items())]
    return "\n".join(lines) + ("\n" if lines else "")


def parse_hashes(text: str) -> dict[str, str]:
    hashes: dict[str, str] = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        rel, _, digest = line.partition("\t")
        hashes[rel] = digest
    return hashes


def capture(snapshot_dir: Path, hashfile: Path) -> None:
    hashfile.write_text(serialize_hashes(compute_hashes(snapshot_dir)), encoding="utf-8")


def diff_hashes(before: dict[str, str], after: dict[str, str]) -> list[str]:
    changed: list[str] = []
    for rel in sorted(set(before) | set(after)):
        if before.get(rel) != after.get(rel):
            changed.append(rel)
    return changed


def verify(snapshot_dir: Path, hashfile: Path) -> list[str]:
    before = parse_hashes(hashfile.read_text(encoding="utf-8"))
    after = compute_hashes(snapshot_dir)
    return diff_hashes(before, after)


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv

    if len(args) != 2 or args[0] not in ("capture", "verify"):
        print("usage: verify-helm-snapshot-stability.py <capture|verify> <hashfile>", file=sys.stderr)
        return 2

    command, hashfile_arg = args
    hashfile = Path(hashfile_arg)

    if command == "capture":
        capture(SNAPSHOT_DIR, hashfile)
        print(f"verify-helm-snapshot-stability: captured snapshot hashes to {hashfile}")
        return 0

    if not hashfile.is_file():
        print(f"verify-helm-snapshot-stability: missing captured hashfile: {hashfile}", file=sys.stderr)
        return 1

    changed = verify(SNAPSHOT_DIR, hashfile)
    if changed:
        print(
            "verify-helm-snapshot-stability: helm unittest modified the following snapshot file(s) "
            "as a side effect of running (see GX-22):",
            file=sys.stderr,
        )
        for rel in changed:
            print(f"- {rel}", file=sys.stderr)
        return 1

    print("verify-helm-snapshot-stability: no snapshot file changed as a side effect of this run.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
