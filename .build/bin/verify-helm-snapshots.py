#!/usr/bin/env python3
"""Verify helm-unittest snapshot files keep labels for empty renders."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEST_DIR = ROOT / "src" / "groundx" / "tests"
SNAPSHOT_DIR = TEST_DIR / "__snapshot__"


def snapshot_tests(path: Path) -> list[str]:
    tests: list[str] = []
    current: str | None = None
    has_snapshot = False

    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r'^  - it: "([^"]+)"', line)
        if match:
            if current is not None and has_snapshot:
                tests.append(current)
            current = match.group(1)
            has_snapshot = False
            continue

        if "matchSnapshot:" in line:
            has_snapshot = True

    if current is not None and has_snapshot:
        tests.append(current)

    return tests


def snapshot_labels(path: Path) -> set[str]:
    if not path.exists():
        return set()
    return set(re.findall(r"^'([^']+)':", path.read_text(encoding="utf-8"), flags=re.MULTILINE))


def main() -> int:
    failures: list[str] = []

    for test_file in sorted(TEST_DIR.glob("*_test.yaml")):
        snapshot_file = SNAPSHOT_DIR / f"{test_file.name}.snap"
        expected = snapshot_tests(test_file)
        actual = snapshot_labels(snapshot_file)
        missing = [name for name in expected if name not in actual]
        if missing:
            failures.append(f"{test_file.relative_to(ROOT)} missing snapshot labels: {', '.join(missing)}")

    if failures:
        print("Helm snapshot label verification failed.", file=sys.stderr)
        print("Every matchSnapshot test must have a snapshot label, even when it renders no documents.", file=sys.stderr)
        print("Use explicit empty entries like 'disabled: api': {} for empty renders.", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Helm snapshot label verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
