#!/usr/bin/env python3
"""Verify workspace runner chart wiring that snapshots can miss."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALUES = (
    ROOT / "src" / "groundx" / "tests" / "files" / "values.workspace.yaml",
    ROOT / "src" / "groundx" / "tests" / "files" / "values.workspace-metrics.yaml",
)
CHARTS = (ROOT / "src" / "groundx", ROOT / "helm")


def render_chart(chart: Path) -> str:
    command = ["helm", "template", "workspace-contract", str(chart)]
    for values in VALUES:
        command.extend(("-f", str(values)))
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


def require_count_at_least(text: str, pattern: str, minimum: int, label: str) -> None:
    count = len(re.findall(pattern, text, flags=re.MULTILINE))
    if count < minimum:
        raise AssertionError(f"expected at least {minimum} {label}, found {count}: {pattern}")


def verify_chart(chart: Path) -> list[str]:
    rendered = render_chart(chart)
    namespace = "eyelevel"
    base_url = f"http://workspace-api.{namespace}.svc.cluster.local"
    stale_base_url = f"http://workspace.{namespace}.svc.cluster.local"

    require(rendered, rf"baseURL:\s+{re.escape(base_url)}", "GroundX config workspace.baseURL")
    require(rendered, rf"name:\s+WORKSPACE_RUNNER_BASE_URL\n\s+value:\s+{re.escape(base_url)}", "Partner API runner env")
    require(rendered, r"managed_repo_name_prefix=\"workspace-test\"", "workspace config managed repo prefix")
    require(rendered, r"managed_repo_owner=\"GroundX-Studio\"", "workspace config managed repo owner")
    require(rendered, r"managed_repo_visibility=\"private\"", "workspace config managed repo visibility")
    require(rendered, r"git_provider=\"github\"", "workspace config default git provider")
    require(rendered, r"gitlab_api_base_url=\"https://gitlab\.com/api/v4\"", "workspace config default GitLab API base URL")
    require(rendered, r"workspace_min_free_bytes=1\.048576e\+06", "workspace config free byte guard")
    require(rendered, r"workspace_min_free_percent=5", "workspace config free percent guard")
    require(rendered, r"^  name:\s+workspace-api$", "workspace API Deployment or Service name")
    require(rendered, r"^  name:\s+workspace-api-hpa$", "workspace API HPA name")
    require(rendered, r"name:\s+workspace-api:api", "workspace API external metric")
    require(rendered, r"name:\s+workspace-api:throughput", "workspace API throughput metric")
    require(rendered, r"^  name:\s+workspace-provision$", "workspace provision worker")
    require(rendered, r"^  name:\s+workspace-workspace$", "workspace worker worker")
    require(rendered, r"^  name:\s+workspace-command$", "workspace command worker")
    require(rendered, r"^  name:\s+workspace-publish$", "workspace publish worker")
    require(rendered, r"^  name:\s+workspace-cleanup$", "workspace cleanup worker")
    require(rendered, r"^  name:\s+\"?workspace-test-data\"?$", "workspace service-wide PVC")
    require_count_at_least(
        rendered,
        r"claimName:\s+workspace-test-data",
        6,
        "workspace pod mounts using the service-wide PVC",
    )

    reject(rendered, rf"baseURL:\s+{re.escape(stale_base_url)}", "stale workspace family baseURL")
    reject(rendered, rf"name:\s+WORKSPACE_RUNNER_BASE_URL\n\s+value:\s+{re.escape(stale_base_url)}", "stale Partner API runner env")
    reject(rendered, r"name:\s+workspace:api", "stale workspace API metric")
    reject(rendered, r"name:\s+workspace:throughput", "stale workspace throughput metric")
    reject(rendered, r"emptyDir:\s+\{\}\n\s+name:\s+workspace-data", "workspace emptyDir cache volume")

    return [f"{chart.relative_to(ROOT)} workspace chart contract passed"]


def main() -> int:
    failures: list[str] = []
    successes: list[str] = []

    for chart in CHARTS:
        if not chart.exists():
            continue
        try:
            successes.extend(verify_chart(chart))
        except (AssertionError, RuntimeError) as exc:
            failures.append(f"{chart.relative_to(ROOT)}: {exc}")

    if not successes:
        failures.append("no chart surfaces found to verify")

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
