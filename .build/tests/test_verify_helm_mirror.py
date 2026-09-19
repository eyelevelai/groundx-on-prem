from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-helm-mirror.py"
    spec = importlib.util.spec_from_file_location("verify_helm_mirror", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_identical_mirrors_pass():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        src = Path(directory) / "src" / "groundx" / "templates"
        mirror = Path(directory) / "helm" / "templates"
        (src / "app").mkdir(parents=True)
        (mirror / "app").mkdir(parents=True)
        (src / "app" / "celery.yaml").write_text("kind: Deployment\n", encoding="utf-8")
        (mirror / "app" / "celery.yaml").write_text("kind: Deployment\n", encoding="utf-8")

        assert guard.compare_trees(src, mirror) == []


def test_differing_mirror_file_is_rejected():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        src = Path(directory) / "src" / "groundx" / "templates"
        mirror = Path(directory) / "helm" / "templates"
        (src / "app").mkdir(parents=True)
        (mirror / "app").mkdir(parents=True)
        (src / "app" / "celery.yaml").write_text("kind: Deployment\n", encoding="utf-8")
        (mirror / "app" / "celery.yaml").write_text("kind: StatefulSet\n", encoding="utf-8")

        failures = guard.compare_trees(src, mirror)

        assert any("app/celery.yaml" in failure and "differ" in failure for failure in failures)


def test_file_present_on_only_one_side_is_rejected():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        src = Path(directory) / "src" / "groundx" / "templates"
        mirror = Path(directory) / "helm" / "templates"
        (src / "app").mkdir(parents=True)
        mirror.mkdir(parents=True)
        (src / "app" / "celery.yaml").write_text("kind: Deployment\n", encoding="utf-8")

        failures = guard.compare_trees(src, mirror)

        assert any("app/celery.yaml" in failure and "only" in failure for failure in failures)


def main() -> int:
    test_identical_mirrors_pass()
    test_differing_mirror_file_is_rejected()
    test_file_present_on_only_one_side_is_rejected()
    print("verify-helm-mirror tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
