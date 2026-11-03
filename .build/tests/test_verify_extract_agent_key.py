from __future__ import annotations

import importlib.util
from pathlib import Path

VAR = "GROUNDX_AGENT_API_KEY"


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-extract-agent-key.py"
    spec = importlib.util.spec_from_file_location("verify_extract_agent_key", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def container(env_from: list[str]) -> dict:
    return {"envFrom": [{"secretRef": {"name": name}} for name in env_from]}


SECRETS = {
    "extract-agent-secret": {VAR: "agent-key"},
    "shared": {VAR: "shared-key"},
}


def test_agent_secret_before_conflicting_shared_secret_resolves_to_shared_key():
    guard = load_guard()
    assert guard.resolve(container(["extract-agent-secret", "shared"]), SECRETS) == "shared-key"


def test_agent_secret_last_resolves_to_agent_key():
    guard = load_guard()
    assert guard.resolve(container(["shared", "extract-agent-secret"]), SECRETS) == "agent-key"


def test_check_records_failure_when_agent_secret_is_not_last():
    guard = load_guard()
    documents = [{"kind": "Secret", "metadata": {"name": "extract-agent-secret"}, "stringData": {VAR: "agent-key"}}]
    documents += [
        {
            "kind": "Deployment",
            "metadata": {"name": w},
            "spec": {"template": {"spec": {"containers": [container(["extract-agent-secret", "zzz-conflict"])]}}},
        }
        for w in guard.WORKLOADS
    ]
    guard.render = lambda chart, sets, secrets: documents
    failures: list[str] = []
    guard.check("src/groundx", "in-cluster summary", {}, ["zzz-conflict"], "agent-key", failures)
    assert len(failures) == len(guard.WORKLOADS)


def test_check_passes_when_agent_secret_is_last():
    guard = load_guard()
    documents = [{"kind": "Secret", "metadata": {"name": "extract-agent-secret"}, "stringData": {VAR: "agent-key"}}]
    documents += [
        {
            "kind": "Deployment",
            "metadata": {"name": w},
            "spec": {"template": {"spec": {"containers": [container(["zzz-conflict", "extract-agent-secret"])]}}},
        }
        for w in guard.WORKLOADS
    ]
    guard.render = lambda chart, sets, secrets: documents
    failures: list[str] = []
    guard.check("src/groundx", "in-cluster summary", {}, ["zzz-conflict"], "agent-key", failures)
    assert failures == []


def test_hosted_without_key_keeps_shared_key_and_passes():
    guard = load_guard()
    documents = [
        {
            "kind": "Deployment",
            "metadata": {"name": w},
            "spec": {"template": {"spec": {"containers": [container(["zzz-conflict"])]}}},
        }
        for w in guard.WORKLOADS
    ]
    guard.render = lambda chart, sets, secrets: documents
    failures: list[str] = []
    guard.check("src/groundx", "hosted without a values key", {}, ["zzz-conflict"], guard.SHARED_KEY, failures)
    assert failures == []


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
    print("test_verify_extract_agent_key passed")
