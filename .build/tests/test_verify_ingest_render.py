from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-ingest-render.py"
    spec = importlib.util.spec_from_file_location("verify_ingest_render", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


REQUIRED_SIBLING_DOCS = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: layout-api
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: summary-api
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: layout-inference
"""

FORBIDDEN_DEPLOYMENT_DOC = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ranker-api
"""

FORBIDDEN_PVC_DOC = """
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ranker-model
"""

FORBIDDEN_DEPLOYMENT_INFERENCE_DOC = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ranker-inference
"""

FORBIDDEN_SERVICE_DOC = """
apiVersion: v1
kind: Service
metadata:
  name: ranker-api
"""

FORBIDDEN_SECRET_DOC = """
apiVersion: v1
kind: Secret
metadata:
  name: ranker-config-py-map
"""

FORBIDDEN_CONFIGMAP_GUNICORN_DOC = """
apiVersion: v1
kind: ConfigMap
metadata:
  name: ranker-gunicorn-conf-py-map
"""

FORBIDDEN_CONFIGMAP_SUPERVISORD_DOC = """
apiVersion: v1
kind: ConfigMap
metadata:
  name: ranker-inference-supervisord-conf-map
"""

GPU_LABEL_DOC = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: layout-inference
spec:
  template:
    spec:
      nodeSelector:
        eyelevel-gpu-ranker: "true"
"""


def test_known_good_render_has_no_failures():
    guard = load_guard()
    text = REQUIRED_SIBLING_DOCS
    assert guard.check_render("src/groundx", text) == []


def test_known_bad_render_with_ranker_deployment_and_siblings_fails():
    guard = load_guard()
    text = FORBIDDEN_DEPLOYMENT_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == ["src/groundx: mode=ingest must not render Deployment=['ranker-api']."]


def test_forbidden_pvc_alone_fails_even_with_no_ranker_deployment():
    guard = load_guard()
    text = FORBIDDEN_PVC_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == [
        "src/groundx: mode=ingest must not render PersistentVolumeClaim=['ranker-model']."
    ]


def test_forbidden_deployment_ranker_inference_alone_fails():
    guard = load_guard()
    text = FORBIDDEN_DEPLOYMENT_INFERENCE_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == [
        "src/groundx: mode=ingest must not render Deployment=['ranker-inference']."
    ]


def test_forbidden_service_ranker_api_alone_fails():
    guard = load_guard()
    text = FORBIDDEN_SERVICE_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == ["src/groundx: mode=ingest must not render Service=['ranker-api']."]


def test_forbidden_secret_ranker_config_py_map_alone_fails():
    guard = load_guard()
    text = FORBIDDEN_SECRET_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == [
        "src/groundx: mode=ingest must not render Secret=['ranker-config-py-map']."
    ]


def test_forbidden_configmap_gunicorn_conf_alone_fails():
    guard = load_guard()
    text = FORBIDDEN_CONFIGMAP_GUNICORN_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == [
        "src/groundx: mode=ingest must not render ConfigMap=['ranker-gunicorn-conf-py-map']."
    ]


def test_forbidden_configmap_supervisord_conf_alone_fails():
    guard = load_guard()
    text = FORBIDDEN_CONFIGMAP_SUPERVISORD_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == [
        "src/groundx: mode=ingest must not render ConfigMap=['ranker-inference-supervisord-conf-map']."
    ]


def test_over_blocking_render_missing_a_required_sibling_fails():
    guard = load_guard()
    text = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: summary-api
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: layout-inference
"""
    failures = guard.check_render("src/groundx", text)
    assert failures == [
        "src/groundx: mode=ingest must still render sibling services ['layout-api']; "
        "a guard that also drops these is over-blocking, not fixed."
    ]


def test_empty_render_fails_closed_on_missing_siblings():
    guard = load_guard()
    failures = guard.check_render("src/groundx", "")
    assert failures == [
        "src/groundx: mode=ingest must still render sibling services "
        "['layout-api', 'layout-inference', 'summary-api']; "
        "a guard that also drops these is over-blocking, not fixed."
    ]


def test_gpu_ranker_node_label_reference_fails_even_off_forbidden_kinds():
    guard = load_guard()
    text = GPU_LABEL_DOC + "---" + REQUIRED_SIBLING_DOCS
    failures = guard.check_render("src/groundx", text)
    assert failures == [
        "src/groundx: mode=ingest must not reference the eyelevel-gpu-ranker node label."
    ]


def test_main_exits_1_on_known_bad_render():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        render_path = Path(directory) / "render.yaml"
        render_path.write_text(FORBIDDEN_DEPLOYMENT_DOC + "---" + REQUIRED_SIBLING_DOCS, encoding="utf-8")
        assert guard.main(["verify-ingest-render.py", "src/groundx", str(render_path)]) == 1


def test_main_exits_0_on_known_good_render():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        render_path = Path(directory) / "render.yaml"
        render_path.write_text(REQUIRED_SIBLING_DOCS, encoding="utf-8")
        assert guard.main(["verify-ingest-render.py", "src/groundx", str(render_path)]) == 0


def main() -> int:
    test_known_good_render_has_no_failures()
    test_known_bad_render_with_ranker_deployment_and_siblings_fails()
    test_forbidden_pvc_alone_fails_even_with_no_ranker_deployment()
    test_forbidden_deployment_ranker_inference_alone_fails()
    test_forbidden_service_ranker_api_alone_fails()
    test_forbidden_secret_ranker_config_py_map_alone_fails()
    test_forbidden_configmap_gunicorn_conf_alone_fails()
    test_forbidden_configmap_supervisord_conf_alone_fails()
    test_over_blocking_render_missing_a_required_sibling_fails()
    test_empty_render_fails_closed_on_missing_siblings()
    test_gpu_ranker_node_label_reference_fails_even_off_forbidden_kinds()
    test_main_exits_1_on_known_bad_render()
    test_main_exits_0_on_known_good_render()
    print("verify-ingest-render tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
