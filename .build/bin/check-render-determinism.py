#!/usr/bin/env python3
"""Render a Helm chart twice from identical values and assert byte-identical output."""

from __future__ import annotations

import argparse
import difflib
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

FLIP_CONDITION_MESSAGE = (
    "warn-only, permanently (see GX-22): this check renders through the helm binary directly, so it "
    "can only ever observe a chart-template-level defect. It structurally cannot observe a defect in "
    "the helm-unittest plugin's own snapshot cache/serializer, which is GX-22's actual root cause, so "
    "an observed-clean render here proves nothing about that defect class and must never be used to "
    "flip this check to blocking."
)


def _helm_command(chart: Path, values: list[str]) -> list[str]:
    command = shlex.split(os.environ.get("HELM_BIN", "helm"), posix=(os.name != "nt"))
    command += ["template", "render-determinism-check", str(chart)]
    for value in values:
        command += ["-f", str(value)]
    return command


def _run_helm(chart: Path, values: list[str], root: Path) -> str:
    command = _helm_command(chart, values)
    result = subprocess.run(
        command,
        cwd=str(root),
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(command)} failed:\n{result.stderr}")
    return result.stdout


def render_and_diff(
    chart: Path,
    values: list[str],
    root: Path,
    focus: str | None = None,
) -> list[str]:
    first = _run_helm(chart, values, root)
    second = _run_helm(chart, values, root)

    if first == second:
        return []

    diff_lines = list(
        difflib.unified_diff(
            first.splitlines(),
            second.splitlines(),
            fromfile="render-1",
            tofile="render-2",
            lineterm="",
        )
    )

    if focus:
        pattern = re.compile(focus)
        diff_lines = [
            line
            for line in diff_lines
            if line.startswith(("+", "-"))
            and not line.startswith(("+++", "---"))
            and pattern.search(line)
        ]

    return diff_lines


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Render a Helm chart twice and assert the two renders are byte-identical."
    )
    parser.add_argument("--chart", required=True, help="Chart directory to render")
    parser.add_argument(
        "--values",
        action="append",
        default=[],
        help="Values file to pass via -f (repeatable)",
    )
    parser.add_argument(
        "--focus",
        default=None,
        help="Regex; only diff lines matching it decide pass/fail",
    )
    parser.add_argument(
        "--warn-only",
        action="store_true",
        help="Report drift without failing the gate (GX-22 interim landing mode)",
    )
    parser.add_argument("--root", default=".", help="Working directory for the helm invocations")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    chart = Path(args.chart)
    root = Path(args.root)

    try:
        diff = render_and_diff(chart=chart, values=args.values, root=root, focus=args.focus)
    except RuntimeError as exc:
        print(f"check-render-determinism: {exc}", file=sys.stderr)
        return 1

    if not diff:
        print(f"check-render-determinism: {chart} renders identically across two runs.")
        return 0

    print(f"check-render-determinism: detected non-deterministic render output for {chart}:")
    for line in diff:
        print(line)

    if args.warn_only:
        print(FLIP_CONDITION_MESSAGE)
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
