#!/usr/bin/env python3
"""Verify helm-unittest snapshot files keep labels for empty renders."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEST_DIR = ROOT / "src" / "groundx" / "tests"
SNAPSHOT_DIR = TEST_DIR / "__snapshot__"
REQUIRED_EMPTY_LABELS = {
    "api_test.yaml.snap": ("disabled: api",),
    "cache_test.yaml.snap": (
        "aws: cache",
        "existing: cache",
        "disabled: cache",
        "extract: cache",
        "extract.ingest: cache",
        "extract.oai: cache",
        "workspace-enabled: cache",
    ),
    "celery_test.yaml.snap": ("disabled: celery",),
    "extract_test.yaml.snap": ("workspace-enabled: extract",),
    "golang_test.yaml.snap": ("disabled: golang", "workspace-enabled: golang"),
    "inference_test.yaml.snap": ("disabled: inference", "workspace-enabled: inference"),
    "resources_test.yaml.snap": ("disabled: resources",),
    "stream_test.yaml.snap": (
        "aws: stream",
        "existing: stream",
        "disabled: stream",
        "extract: stream",
        "extract.ingest: stream",
        "extract.oai: stream",
        "workspace-enabled: stream",
    ),
    "workspace_test.yaml.snap": ("disabled: workspace", "disabled: workspace metrics config"),
}


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


def snapshot_label_order(path: Path) -> list[str]:
    if not path.exists():
        return []
    return re.findall(r"^'([^']+)':", path.read_text(encoding="utf-8"), flags=re.MULTILINE)


def snapshot_label_sort_key(label: str) -> tuple[str, str]:
    case, separator, surface = label.partition(": ")
    if separator:
        return case, surface
    return label, ""


def snapshot_entries(path: Path) -> list[tuple[str, str, str]]:
    if not path.exists():
        return []

    text = path.read_text(encoding="utf-8")
    matches = list(re.finditer(r"^'([^']+)':.*$", text, flags=re.MULTILINE))
    entries: list[tuple[str, str, str]] = []
    for index, match in enumerate(matches):
        line_end = text.find("\n", match.start())
        if line_end == -1:
            line_end = len(text)
            body_start = len(text)
        else:
            body_start = line_end + 1

        next_start = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        entries.append((match.group(1), match.group(0), text[body_start:next_start]))

    return entries


def empty_snapshot_labels(path: Path) -> set[str]:
    labels: set[str] = set()
    for label, line, body in snapshot_entries(path):
        if re.match(r"^'[^']+':\s+\{\}\s*$", line) or body.strip() == "":
            labels.add(label)

    return labels


def nonlegacy_empty_snapshot_labels(path: Path) -> set[str]:
    labels: set[str] = set()
    for label, line, body in snapshot_entries(path):
        is_empty = re.match(r"^'[^']+':\s+\{\}\s*$", line) or body.strip() == ""
        if is_empty and (re.match(r"^'[^']+':\s+\{\}\s*$", line) or body != ""):
            labels.add(label)
    return labels


def deleted_snapshot_labels_from_diff(diff: str) -> list[str]:
    deleted_by_file: dict[str, list[str]] = {}
    added_by_file: dict[str, set[str]] = {}
    current_file = ""
    for line in diff.splitlines():
        file_match = re.match(r"^diff --git a/(.+?) b/", line)
        if file_match:
            current_file = file_match.group(1)
            deleted_by_file.setdefault(current_file, [])
            added_by_file.setdefault(current_file, set())
            continue

        deleted_match = re.match(r"^-('([^']+)'):\s*(?:\{\})?\s*$", line)
        if deleted_match and current_file:
            deleted_by_file.setdefault(current_file, []).append(deleted_match.group(1))
            continue

        added_match = re.match(r"^\+('([^']+)'):\s*(?:\{\})?\s*$", line)
        if added_match and current_file:
            added_by_file.setdefault(current_file, set()).add(added_match.group(1))

    deleted: list[str] = []
    for file_name, labels in deleted_by_file.items():
        added = added_by_file.get(file_name, set())
        for label in labels:
            if label not in added:
                deleted.append(f"{file_name}: {label}")

    return deleted


def deleted_snapshot_labels() -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--", str(SNAPSHOT_DIR.relative_to(ROOT))],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode not in (0, 1):
        return [f"unable to inspect git diff: {result.stderr.strip()}"]

    return deleted_snapshot_labels_from_diff(result.stdout)


def snapshot_path_label(name: str) -> str:
    return f"src/groundx/tests/__snapshot__/{name}"


def verify_snapshot_labels(
    *,
    test_dir: Path,
    snapshot_dir: Path,
    required_empty_labels: dict[str, tuple[str, ...] | set[str]],
    diff_output: str | None = None,
) -> list[str]:
    failures: list[str] = []

    for test_file in sorted(test_dir.glob("*_test.yaml")):
        snapshot_file = snapshot_dir / f"{test_file.name}.snap"
        expected = snapshot_tests(test_file)
        actual = snapshot_labels(snapshot_file)
        missing = [name for name in expected if name not in actual]
        if missing:
            failures.append(f"{test_file.relative_to(ROOT)} missing snapshot labels: {', '.join(missing)}")

        labels = snapshot_label_order(snapshot_file)
        for current, next_label in zip(labels, labels[1:]):
            if snapshot_label_sort_key(current) > snapshot_label_sort_key(next_label):
                failures.append(
                    f"{snapshot_path_label(snapshot_file.name)} snapshot labels must be sorted: "
                    f"{current} before {next_label}"
                )
                break

    for name, labels in required_empty_labels.items():
        snapshot_file = snapshot_dir / name
        actual_empty = empty_snapshot_labels(snapshot_file)
        missing_empty = [label for label in labels if label not in actual_empty]
        if missing_empty:
            failures.append(
                f"{snapshot_path_label(name)} required empty snapshot labels missing or rendered: "
                + ", ".join(missing_empty)
            )

        nonlegacy_empty = nonlegacy_empty_snapshot_labels(snapshot_file)
        if nonlegacy_empty:
            failures.append(
                f"{snapshot_path_label(name)} empty snapshot labels must use label-only shape without spacer lines: "
                + ", ".join(sorted(nonlegacy_empty, key=snapshot_label_sort_key))
            )

    deleted = deleted_snapshot_labels_from_diff(diff_output) if diff_output is not None else deleted_snapshot_labels()
    if deleted:
        failures.append(
            "snapshot label deletions found in git diff; helm-unittest may have silently removed empty renders: "
            + ", ".join(deleted)
        )

    return failures


def main() -> int:
    failures = verify_snapshot_labels(
        test_dir=TEST_DIR,
        snapshot_dir=SNAPSHOT_DIR,
        required_empty_labels=REQUIRED_EMPTY_LABELS,
    )

    if failures:
        print("Helm snapshot label verification failed.", file=sys.stderr)
        print("Every matchSnapshot test must have a snapshot label, even when it renders no documents.", file=sys.stderr)
        print(
            "Use explicit empty entries like 'disabled: api': {} for empty renders, and do not leave deleted label lines in the diff.",
            file=sys.stderr,
        )
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Helm snapshot label verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
