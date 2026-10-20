#!/usr/bin/env python3
"""Read-only preflight for one CloudWatch publisher per SageMaker variant."""
from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path
import subprocess
import yaml


def configurations(text):
    result = []
    for obj in yaml.safe_load_all(text):
        if not isinstance(obj, dict):
            continue
        if isinstance(obj.get("metrics"), dict):
            result.append({"metrics": obj["metrics"]})
        if obj.get("kind") not in ("Secret", "ConfigMap"):
            continue
        raw = obj.get("stringData", {}).get("config.yaml")
        if raw is None and "config.yaml" in obj.get("data", {}):
            raw = obj["data"]["config.yaml"]
            if obj["kind"] == "Secret":
                raw = base64.b64decode(raw, validate=True).decode()
        if raw is not None:
            cfg = yaml.safe_load(raw)
            if isinstance(cfg, dict) and isinstance(cfg.get("metrics"), dict):
                result.append({"metrics": cfg["metrics"]})
    return result


def targets(cfg):
    out = set()
    for item in cfg.get("metrics", {}).get("throughput", []) or []:
        target = item.get("sagemaker")
        if target and target.get("publish") is True:
            identity = tuple(str(target.get(key, "")) for key in ("accountId", "region", "endpoint", "variant"))
            if not all(identity) or identity in out:
                raise ValueError("incomplete or duplicate SageMaker publishing target")
            out.add(identity)
    return out


def verify(candidate, owner, installed):
    wanted = targets(candidate)
    for other_owner, config in installed:
        if other_owner != owner and wanted.intersection(targets(config)):
            raise ValueError("SageMaker variant has another publisher: " + other_owner)


def read(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=60)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        raise ValueError("publisher inventory could not be verified") from None


def cluster_id(context):
    return json.loads(read("kubectl", "--context", context, "get", "namespace", "kube-system", "-o", "json"))["metadata"]["uid"]


def installed_configurations(contexts):
    seen = set()
    for context in contexts:
        identity = cluster_id(context)
        if identity in seen:
            continue
        seen.add(identity)
        offset = 0
        while True:
            releases = json.loads(read("helm", "--kube-context", context, "list", "--all-namespaces", "--all", "--max", "256", "--offset", str(offset), "-o", "json"))
            for release in releases:
                if not release.get("chart", "").startswith("groundx-"):
                    continue
                owner = "/".join((identity, release["namespace"], release["name"]))
                manifest = read("helm", "--kube-context", context, "get", "manifest", release["name"], "-n", release["namespace"])
                for cfg in configurations(manifest):
                    yield owner, cfg
            if len(releases) < 256:
                break
            offset += len(releases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True, help="Private helm-template manifest or rendered application config")
    parser.add_argument("--context", required=True, help="Candidate deployment's kube context")
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--release", required=True)
    args = parser.parse_args()
    candidate = configurations(args.candidate.read_text())
    if not any(targets(cfg) for cfg in candidate):
        print("No SageMaker publisher enabled")
        return
    contexts = read("kubectl", "config", "get-contexts", "-o", "name").splitlines()
    if args.context not in contexts:
        raise ValueError("candidate context is not in the inventoried contexts")
    owner = "/".join((cluster_id(args.context), args.namespace, args.release))
    installed = list(installed_configurations(contexts))
    for cfg in candidate:
        verify(cfg, owner, installed)
    print("SageMaker publisher ownership verified across configured clusters")


if __name__ == "__main__":
    main()
