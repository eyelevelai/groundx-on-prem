#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CREDENTIALS = "src/groundx/tests/files/values.search-credentials.yaml"
WORKSPACE = "src/groundx/tests/files/values.workspace.enabled.yaml"
EXTRACT = "src/groundx/values/extract/values.yaml"
CHAINGUARD = "src/groundx/values/chainguard/values.yaml"

EXTRACT_SERVICES = ("extract-agent", "extract-download", "extract-save")
CELERY_SERVICES = frozenset(
    EXTRACT_SERVICES
    + (
        "layout-correct",
        "layout-map",
        "layout-ocr",
        "layout-process",
        "layout-save",
        "layout-inference",
        "ranker-inference",
        "summary-inference",
        "workspace-cleanup",
        "workspace-command",
        "workspace-provision",
        "workspace-publish",
        "workspace-workspace",
    )
)
WORKER_FAMILIES = (
    "extract.agent",
    "extract.download",
    "extract.save",
    "layout.correct",
    "layout.map",
    "layout.ocr",
    "layout.process",
    "layout.save",
    "layout.inference",
    "ranker.inference",
    "summary.inference",
    "workspace.cleanup",
    "workspace.command",
    "workspace.provision",
    "workspace.publish",
    "workspace.workspace",
)

BASE_FILES = [CREDENTIALS]
ALL_FILES = [CREDENTIALS, EXTRACT, WORKSPACE]


def sets(path_suffix: str, value: int) -> list[str]:
    args: list[str] = []
    for family in WORKER_FAMILIES:
        args += ["--set", f"{family}.{path_suffix}={value}"]
    return args


def combos() -> dict[str, list[str]]:
    def files(names: list[str]) -> list[str]:
        args: list[str] = []
        for name in names:
            args += ["-f", name]
        return args

    return {
        "default": files(BASE_FILES),
        "all-enabled": files(ALL_FILES),
        "grace-period-set": files(ALL_FILES) + sets("replicas.gracePeriod", 120),
        "cache-valkey": files(ALL_FILES) + ["--set", "cache.existing.type=valkey"],
        "chainguard": files(ALL_FILES + [CHAINGUARD]),
        "workers-2": files(ALL_FILES) + sets("workers", 2),
        "workers-3": files(ALL_FILES) + sets("workers", 3),
        "mode-ingest": files(ALL_FILES) + ["--set", "mode=ingest"],
    }


def split_documents(render: str) -> list[str]:
    docs = re.split(r"(?m)^---\s*$", render)
    return [doc for doc in docs if doc.strip()]


def doc_identity(doc: str) -> tuple[str, str]:
    kind = re.search(r"(?m)^kind:\s*(\S+)", doc)
    name = re.search(r"(?m)^metadata:\s*\n(?:[ \t]+.*\n)*?[ \t]+name:\s*\"?([^\s\"]+)\"?", doc)
    if kind is None or name is None:
        raise ValueError("rendered document without kind or metadata.name")
    return kind.group(1), name.group(1)


def worker_documents(render: str) -> dict[str, str]:
    selected: dict[str, str] = {}
    for doc in split_documents(render):
        kind, name = doc_identity(doc)
        is_conf = kind == "ConfigMap" and name.endswith("-supervisord-conf-map")
        is_worker = kind == "Deployment" and "supervisord -c" in doc
        if is_conf or is_worker:
            selected[f"{kind}/{name}"] = doc
    return selected


GROUP_PROGRAMS = re.compile(
    r"(?m)^[ \t]*\[group:celery_workers\][ \t]*\n[ \t]*programs=(\S+)[ \t]*\n?"
)
WORKER_PROGRAM = re.compile(r"(?m)^[ \t]*\[program:(celery_worker_\d+)\]")


def collapse_blank_lines(text: str) -> str:
    return re.sub(r"\n[ \t]*\n(?:[ \t]*\n)+", "\n\n", text)


def strip_extract_group(doc: str) -> tuple[str, list[str]]:
    groups = GROUP_PROGRAMS.findall(doc)
    stripped = GROUP_PROGRAMS.sub("", doc)
    return collapse_blank_lines(stripped).rstrip() + "\n", groups


def drop_supervisord_hash(doc: str) -> str:
    return re.sub(r"(?m)^[ \t]*supervisord-hash:.*\n", "", doc)


def compare(base: dict[str, str], branch: dict[str, str]) -> list[str]:
    problems: list[str] = []
    if set(base) != set(branch):
        problems.append(
            "worker document set differs: only-in-base="
            f"{sorted(set(base) - set(branch))} only-in-branch={sorted(set(branch) - set(base))}"
        )
    for key in sorted(set(base) & set(branch)):
        _, name = key.split("/", 1)
        base_doc, branch_doc = base[key], branch[key]
        if name in EXTRACT_SERVICES or re.sub(r"-supervisord-conf-map$", "", name) in EXTRACT_SERVICES:
            if key.startswith("ConfigMap/"):
                programs = WORKER_PROGRAM.findall(branch_doc)
                stripped, groups = strip_extract_group(branch_doc)
                if len(groups) != 1 or groups[0].split(",") != programs or not programs:
                    problems.append(
                        f"{key}: expected exactly one [group:celery_workers] listing {programs}, got {groups}"
                    )
                if collapse_blank_lines(base_doc).rstrip() + "\n" != stripped:
                    problems.append(f"{key}: differs from base beyond the added group section")
            elif drop_supervisord_hash(base_doc) != drop_supervisord_hash(branch_doc):
                problems.append(f"{key}: differs from base beyond supervisord-hash")
        elif base_doc != branch_doc:
            problems.append(f"{key}: not byte-identical to base")
    return problems


def helm_binary() -> str:
    path = os.environ.get("GX_ON_PREM_HELM") or shutil.which("helm")
    if not path:
        raise RuntimeError("helm not found on PATH and GX_ON_PREM_HELM unset")
    return path


def run(command: list[str], cwd: Path) -> str:
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(command[:3])} failed: {result.stderr.strip()[:500]}")
    return result.stdout


def base_ref() -> str:
    explicit = os.environ.get("GX_RENDER_BASE")
    if explicit:
        return explicit
    return run(["git", "merge-base", "HEAD", "origin/main"], ROOT).strip()


def export_base(ref: str, target: Path) -> None:
    archive = subprocess.run(
        ["git", "archive", ref, "src/groundx", "helm"], cwd=ROOT, capture_output=True
    )
    if archive.returncode != 0:
        raise RuntimeError(f"git archive {ref} failed: {archive.stderr.decode()[:300]}")
    untar = subprocess.run(["tar", "-x", "-C", str(target)], input=archive.stdout, capture_output=True)
    if untar.returncode != 0:
        raise RuntimeError(f"tar extract failed: {untar.stderr.decode()[:300]}")


def render(helm: str, tree: Path, chart: str, args: list[str]) -> str:
    return run([helm, "template", "r", chart, *args], tree)


def main() -> int:
    try:
        helm = helm_binary()
        ref = base_ref()
        failures: list[str] = []
        covered: set[str] = set()
        with tempfile.TemporaryDirectory() as tmp:
            base_tree = Path(tmp)
            export_base(ref, base_tree)
            for label, args in combos().items():
                base_render = render(helm, base_tree, "src/groundx", args)
                branch_render = render(helm, ROOT, "src/groundx", args)
                mirror_render = render(helm, ROOT, "helm", args)
                base_docs = worker_documents(base_render)
                branch_docs = worker_documents(branch_render)
                covered |= {k.split("/", 1)[1] for k in branch_docs if k.startswith("Deployment/")}
                for problem in compare(base_docs, branch_docs):
                    failures.append(f"[{label}] {problem}")
                if branch_render != mirror_render:
                    failures.append(f"[{label}] helm/ render differs from src/groundx render")
        missing = sorted(CELERY_SERVICES - covered)
        if missing:
            failures.append(f"no combination rendered Celery services: {missing}")
    except (RuntimeError, ValueError, OSError) as exc:
        print(f"verify-celery-render-identity: cannot decide: {exc}", file=sys.stderr)
        return 2
    if failures:
        for failure in failures:
            print(f"FAIL {failure}", file=sys.stderr)
        return 1
    print(f"celery render identity holds against {ref} for {len(combos())} value combinations")
    return 0


if __name__ == "__main__":
    sys.exit(main())
