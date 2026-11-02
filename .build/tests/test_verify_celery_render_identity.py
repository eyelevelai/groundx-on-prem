from __future__ import annotations

import importlib.util
from pathlib import Path


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-celery-render-identity.py"
    spec = importlib.util.spec_from_file_location("verify_celery_render_identity", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


CONF = (
    "data:\n  supervisord.conf: |\n    [supervisord]\n    nodaemon=true\n\n"
    "    [program:celery_worker_1]\n    stopwaitsecs=870\n"
)
GROUP = "\n    [group:celery_workers]\n    programs=celery_worker_1\n"


def test_extract_config_with_only_the_group_added_passes():
    guard = load_guard()
    key = "ConfigMap/extract-agent-supervisord-conf-map"
    assert guard.compare({key: CONF}, {key: CONF + GROUP}) == []


def test_extract_config_already_grouped_in_base_and_identical_passes():
    guard = load_guard()
    key = "ConfigMap/extract-agent-supervisord-conf-map"
    assert guard.compare({key: CONF + GROUP}, {key: CONF + GROUP}) == []


def test_extract_config_already_grouped_in_base_and_changed_is_rejected():
    guard = load_guard()
    key = "ConfigMap/extract-agent-supervisord-conf-map"
    changed = (CONF + GROUP).replace("870", "1")
    assert guard.compare({key: CONF + GROUP}, {key: changed}) != []
    assert guard.compare({key: CONF + GROUP}, {key: CONF}) != []


def test_extract_config_without_the_group_is_rejected():
    guard = load_guard()
    key = "ConfigMap/extract-agent-supervisord-conf-map"
    assert guard.compare({key: CONF}, {key: CONF}) != []


def test_extract_config_changed_beyond_the_group_is_rejected():
    guard = load_guard()
    key = "ConfigMap/extract-agent-supervisord-conf-map"
    changed = CONF.replace("870", "1") + GROUP
    assert guard.compare({key: CONF}, {key: changed}) != []


def test_group_listing_only_the_first_of_two_workers_is_rejected():
    guard = load_guard()
    key = "ConfigMap/extract-save-supervisord-conf-map"
    two = CONF + "\n    [program:celery_worker_2]\n    stopwaitsecs=870\n"
    assert guard.compare({key: two}, {key: two + GROUP}) != []


def test_non_extract_config_must_be_byte_identical():
    guard = load_guard()
    key = "ConfigMap/summary-inference-supervisord-conf-map"
    assert guard.compare({key: CONF}, {key: CONF}) == []
    assert guard.compare({key: CONF}, {key: CONF.replace("870", "1")}) != []


def test_non_extract_config_gaining_a_group_is_rejected():
    guard = load_guard()
    key = "ConfigMap/summary-inference-supervisord-conf-map"
    assert guard.compare({key: CONF}, {key: CONF + GROUP}) != []


def test_extract_deployment_may_change_only_its_supervisord_hash():
    guard = load_guard()
    key = "Deployment/extract-download"
    base = "kind: Deployment\n      annotations:\n        supervisord-hash: aaa\n  x: 1\n"
    assert guard.compare({key: base}, {key: base.replace("aaa", "bbb")}) == []
    assert guard.compare({key: base}, {key: base.replace("x: 1", "x: 2")}) != []


def test_worker_set_difference_is_rejected():
    guard = load_guard()
    assert guard.compare({"Deployment/layout-map": "a"}, {}) != []


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
    print("ok")
