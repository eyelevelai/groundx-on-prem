#!/usr/bin/env python3
"""Verify workspace runner chart wiring that snapshots can miss."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALUES = ROOT / "values.extract.eks.yaml"
CHARTS = (ROOT / "src" / "groundx", ROOT / "helm")


def render_chart(chart: Path) -> str:
    command = ["helm", "template", "workspace-contract", str(chart), "-f", str(VALUES)]
    result = subprocess.run(command, cwd=ROOT, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(command)} failed:\n{result.stderr}")
    return result.stdout


def require(text: str, pattern: str, label: str) -> None:
    if re.search(pattern, text, flags=re.MULTILINE) is None:
        raise AssertionError(f"missing {label}: {pattern}")


def reject(text: str, pattern: str, label: str) -> None:
    if re.search(pattern, text, flags=re.MULTILINE) is not None:
        raise AssertionError(f"unexpected {label}: {pattern}")


def verify_chart(chart: Path) -> list[str]:
    rendered = render_chart(chart)
    namespace = "eyelevel"
    base_url = f"http://workspace-api.{namespace}.svc.cluster.local"
    stale_base_url = f"http://workspace.{namespace}.svc.cluster.local"

    require(rendered, rf"baseURL:\s+{re.escape(base_url)}", "GroundX config workspace.baseURL")
    require(rendered, rf"name:\s+WORKSPACE_RUNNER_BASE_URL\n\s+value:\s+{re.escape(base_url)}", "Partner API runner env")
    require(rendered, r"^  name:\s+workspace-api$", "workspace API Deployment or Service name")
    require(rendered, r"^  name:\s+workspace-api-hpa$", "workspace API HPA name")
    require(rendered, r"name:\s+workspace-api:api", "workspace API external metric")
    require(rendered, r"name:\s+workspace-api:throughput", "workspace API throughput metric")
    require(rendered, r"^  name:\s+workspace-provision$", "workspace provision worker")
    require(rendered, r"^  name:\s+workspace-workspace$", "workspace worker worker")
    require(rendered, r"^  name:\s+workspace-command$", "workspace command worker")
    require(rendered, r"^  name:\s+workspace-publish$", "workspace publish worker")
    require(rendered, r"^  name:\s+workspace-cleanup$", "workspace cleanup worker")

    reject(rendered, rf"baseURL:\s+{re.escape(stale_base_url)}", "stale workspace family baseURL")
    reject(rendered, rf"name:\s+WORKSPACE_RUNNER_BASE_URL\n\s+value:\s+{re.escape(stale_base_url)}", "stale Partner API runner env")
    reject(rendered, r"name:\s+workspace:api", "stale workspace API metric")
    reject(rendered, r"name:\s+workspace:throughput", "stale workspace throughput metric")

    return [f"{chart.relative_to(ROOT)} workspace chart contract passed"]


def main() -> int:
    failures: list[str] = []
    successes: list[str] = []

    for chart in CHARTS:
        try:
            successes.extend(verify_chart(chart))
        except (AssertionError, RuntimeError) as exc:
            failures.append(f"{chart.relative_to(ROOT)}: {exc}")

    if failures:
        print("Workspace chart contract verification failed.", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    for success in successes:
        print(success)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
