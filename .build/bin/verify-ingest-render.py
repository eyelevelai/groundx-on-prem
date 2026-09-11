#!/usr/bin/env python3
"""Verify a `mode: ingest` chart render does not include the ranker microservices."""

from __future__ import annotations

import re
import sys
from pathlib import Path

FORBIDDEN_BY_KIND = {
    "Deployment": {"ranker-api", "ranker-inference"},
    "Service": {"ranker-api"},
    "PersistentVolumeClaim": {"ranker-model"},
    "Secret": {"ranker-config-py-map"},
    "ConfigMap": {"ranker-gunicorn-conf-py-map", "ranker-inference-supervisord-conf-map"},
}

REQUIRED_SIBLINGS = {"layout-api", "summary-api", "layout-inference"}

FORBIDDEN_NODE_LABEL = "eyelevel-gpu-ranker"


def document_names(documents: list[str], kind: str) -> tuple[set[str], int]:
    names: set[str] = set()
    unnamed = 0
    for doc in documents:
        if not re.search(rf"(?m)^kind:\s*{kind}\s*$", doc):
            continue
        match = re.search(r'(?m)^  name:\s*"?([A-Za-z0-9._-]+)"?\s*$', doc)
        if match:
            names.add(match.group(1))
        else:
            unnamed += 1
    return names, unnamed


def check_render(chart: str, text: str) -> list[str]:
    documents = re.split(r"(?m)^---$", text)

    violations = []
    unnamed_kinds = []
    for kind, names in FORBIDDEN_BY_KIND.items():
        found, unnamed = document_names(documents, kind)
        if unnamed:
            unnamed_kinds.append(f"{kind}={unnamed}")
        present = found & names
        if present:
            violations.append(f"{kind}={sorted(present)}")
    if unnamed_kinds:
        return [
            f"{chart}: could not read metadata.name from {'; '.join(unnamed_kinds)} document(s); "
            "the guard cannot prove the ranker is absent, so it fails closed."
        ]
    if violations:
        return [f"{chart}: mode=ingest must not render {'; '.join(violations)}."]

    deployments, _ = document_names(documents, "Deployment")
    missing = REQUIRED_SIBLINGS - deployments
    if missing:
        return [
            f"{chart}: mode=ingest must still render sibling services {sorted(missing)}; "
            "a guard that also drops these is over-blocking, not fixed."
        ]

    if FORBIDDEN_NODE_LABEL in text:
        return [f"{chart}: mode=ingest must not reference the {FORBIDDEN_NODE_LABEL} node label."]

    return []


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {argv[0]} <chart> <render-file>", file=sys.stderr)
        return 2

    chart, render_path = argv[1], argv[2]
    text = Path(render_path).read_text(encoding="utf-8")
    failures = check_render(chart, text)

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
