#!/usr/bin/env python3
"""Resolve each extract workload's GROUNDX_AGENT_API_KEY with Kubernetes precedence."""

from __future__ import annotations

import base64
import json
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
CHARTS = ("src/groundx", "helm")
FIXTURES = (
    "src/groundx/tests/files/values.search-credentials.yaml",
    "src/groundx/tests/files/values.disabled.yaml",
)
WORKLOADS = ("extract-agent", "extract-api", "extract-download", "extract-save")
VAR = "GROUNDX_AGENT_API_KEY"
SUMMARY_KEY = "summary-key"
SHARED_KEY = "openai-api-key"
SHARED = ("eyelevel-secret-credentials", "aaa-conflict", "zzz-conflict")
ORDERS = (
    ["eyelevel-secret-credentials", "aaa-conflict", "zzz-conflict"],
    ["zzz-conflict", "aaa-conflict", "eyelevel-secret-credentials"],
)
BASE_SET = {
    "extract.enabled": "true",
    "extract.agent.enabled": "true",
    "extract.api.enabled": "true",
    "extract.download.enabled": "true",
    "extract.save.enabled": "true",
}
HOSTED_SET = {
    "extract.agent.serviceType": "bedrock",
    "extract.agent.apiBaseUrl": "https://bedrock-mantle.us-west-2.api.aws/openai/v1",
    "extract.agent.modelId": "google.gemma-4-31b",
    "extract.file.bucketName": "configured-bucket",
    "extract.file.region": "us-west-2",
    "extract.file.serviceType": "s3",
    "extract.file.url": "https://configured-bucket.s3.us-west-2.amazonaws.com",
}


def render(chart: str, sets: dict[str, str], secrets: list[str]) -> list[dict]:
    command = ["helm", "template", "agent-key", str(ROOT / chart)]
    for fixture in FIXTURES:
        command += ["-f", str(ROOT / fixture)]
    for key, value in {**BASE_SET, **sets}.items():
        command += ["--set", f"{key}={value}"]
    command += ["--set-json", f"cluster.secrets={json.dumps(secrets)}"]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{chart}: helm template failed: {result.stderr.strip()}")
    return [d for d in yaml.safe_load_all(result.stdout) if isinstance(d, dict)]


def secret_data(documents: list[dict], shared: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    data = {name: dict(values) for name, values in shared.items()}
    for doc in documents:
        if doc.get("kind") != "Secret":
            continue
        values = {k: base64.b64decode(v).decode() for k, v in (doc.get("data") or {}).items()}
        values.update(doc.get("stringData") or {})
        data[doc["metadata"]["name"]] = values
    return data


def resolve(container: dict, secrets: dict[str, dict[str, str]]) -> str | None:
    value = None
    for source in container.get("envFrom") or []:
        ref = source.get("secretRef")
        if ref and VAR in secrets.get(ref["name"], {}):
            value = secrets[ref["name"]][VAR]
    for entry in container.get("env") or []:
        if entry.get("name") != VAR:
            continue
        if "value" in entry:
            value = entry["value"]
        else:
            ref = (entry.get("valueFrom") or {}).get("secretKeyRef")
            if ref and VAR in secrets.get(ref["name"], {}):
                value = secrets[ref["name"]][VAR]
    return value


def check(chart: str, label: str, sets: dict[str, str], order: list[str], expected: str, failures: list[str]) -> None:
    documents = render(chart, sets, order)
    shared = {name: {VAR: SHARED_KEY} for name in SHARED}
    secrets = secret_data(documents, shared)
    deployments = {d["metadata"]["name"]: d for d in documents if d.get("kind") == "Deployment"}
    for workload in WORKLOADS:
        if workload not in deployments:
            failures.append(f"{chart} [{label}] {order}: {workload} was not rendered")
            continue
        containers = deployments[workload]["spec"]["template"]["spec"]["containers"]
        got = resolve(containers[0], secrets)
        if got != expected:
            failures.append(f"{chart} [{label}] {order}: {workload} resolves {VAR}={got!r}, expected {expected!r}")


def main() -> int:
    failures: list[str] = []
    for chart in CHARTS:
        for order in ORDERS:
            check(chart, "in-cluster summary", {"admin.apiKey": SUMMARY_KEY}, order, SUMMARY_KEY, failures)
            check(chart, "hosted without a values key", HOSTED_SET, order, SHARED_KEY, failures)
    if failures:
        print("extract agent key precedence check failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("extract agent key precedence check passed for src/groundx and helm")
    return 0


if __name__ == "__main__":
    sys.exit(main())
