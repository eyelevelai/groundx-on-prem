from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-storage-contract.py"
    spec = importlib.util.spec_from_file_location("verify_storage_contract", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def write_mirrored_tree(root: Path, files: dict[str, str]) -> tuple[Path, Path]:
    src_templates = root / "src" / "groundx" / "templates"
    mirror_templates = root / "helm" / "templates"
    for relative, content in files.items():
        (src_templates / relative).parent.mkdir(parents=True, exist_ok=True)
        (src_templates / relative).write_text(content, encoding="utf-8")
        (mirror_templates / relative).parent.mkdir(parents=True, exist_ok=True)
        (mirror_templates / relative).write_text(content, encoding="utf-8")
    return src_templates, mirror_templates


def test_matching_mirrored_trees_pass(monkeypatch):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        src_templates, mirror_templates = write_mirrored_tree(
            Path(directory),
            {
                "resources/deployment.yaml": "kind: Deployment\n",
                "resources/nested/service.yaml": "kind: Service\n",
            },
        )
        monkeypatch.setattr(guard, "MIRRORED_FILES", ())
        monkeypatch.setattr(guard, "SRC_TEMPLATES", src_templates)
        monkeypatch.setattr(guard, "MIRROR_TEMPLATES", mirror_templates)

        successes = guard.verify_mirrors()

        assert any("resources/deployment.yaml" in item for item in successes)
        assert any("resources/nested/service.yaml" in item for item in successes)


def test_content_drift_is_rejected(monkeypatch):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        src_templates, mirror_templates = write_mirrored_tree(
            Path(directory),
            {"resources/deployment.yaml": "kind: Deployment\n"},
        )
        (mirror_templates / "resources" / "deployment.yaml").write_text(
            "kind: DeploymentDrifted\n", encoding="utf-8"
        )
        monkeypatch.setattr(guard, "MIRRORED_FILES", ())
        monkeypatch.setattr(guard, "SRC_TEMPLATES", src_templates)
        monkeypatch.setattr(guard, "MIRROR_TEMPLATES", mirror_templates)

        try:
            guard.verify_mirrors()
        except AssertionError as exc:
            assert "mirrored file drift" in str(exc)
            assert "resources/deployment.yaml" in str(exc)
        else:
            raise AssertionError("expected AssertionError for a content-drifted mirror file")


def test_file_present_on_only_one_side_is_rejected(monkeypatch):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        src_templates, mirror_templates = write_mirrored_tree(
            Path(directory),
            {"resources/deployment.yaml": "kind: Deployment\n"},
        )
        (src_templates / "resources" / "only-in-src.yaml").write_text("kind: OnlyInSrc\n", encoding="utf-8")
        monkeypatch.setattr(guard, "MIRRORED_FILES", ())
        monkeypatch.setattr(guard, "SRC_TEMPLATES", src_templates)
        monkeypatch.setattr(guard, "MIRROR_TEMPLATES", mirror_templates)

        try:
            guard.verify_mirrors()
        except AssertionError as exc:
            assert "missing mirrored file" in str(exc)
            assert "resources/only-in-src.yaml" in str(exc)
        else:
            raise AssertionError("expected AssertionError for a file present on only one side")


class _FakeMonkeypatch:
    def __init__(self) -> None:
        self._saved: list[tuple[object, str, object]] = []

    def setattr(self, target: object, name: str, value: object) -> None:
        self._saved.append((target, name, getattr(target, name)))
        setattr(target, name, value)

    def undo(self) -> None:
        for target, name, value in reversed(self._saved):
            setattr(target, name, value)


def main() -> int:
    for test in (
        test_matching_mirrored_trees_pass,
        test_content_drift_is_rejected,
        test_file_present_on_only_one_side_is_rejected,
    ):
        monkeypatch = _FakeMonkeypatch()
        try:
            test(monkeypatch)
        finally:
            monkeypatch.undo()
    print("verify-storage-contract verify_mirrors tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
