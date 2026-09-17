from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-helm-unittest-plugin-version.py"
    spec = importlib.util.spec_from_file_location("verify_helm_unittest_plugin_version", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def write_plugin_yaml(plugins_dir: Path, dir_name: str, *, name: str, version: str) -> Path:
    plugin_dir = plugins_dir / dir_name
    plugin_dir.mkdir(parents=True)
    plugin_yaml = plugin_dir / "plugin.yaml"
    plugin_yaml.write_text(f'name: "{name}"\nversion: "{version}"\n', encoding="utf-8")
    return plugin_yaml


def test_pinned_version_reads_and_strips_whitespace():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v1.1.2\n", encoding="utf-8")

        assert guard.pinned_version(pin_file) == "v1.1.2"


def test_installed_version_finds_matching_plugin_by_name():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugins_dir = Path(directory)
        write_plugin_yaml(plugins_dir, "helm-unittest.git", name="unittest", version="1.1.2")

        assert guard.installed_version(plugins_dir) == "1.1.2"


def test_installed_version_ignores_unrelated_plugin_directories():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugins_dir = Path(directory)
        write_plugin_yaml(plugins_dir, "some-other-plugin", name="other", version="9.9.9")

        assert guard.installed_version(plugins_dir) is None


def test_installed_version_returns_none_when_plugins_dir_missing():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        assert guard.installed_version(Path(directory) / "does-not-exist") is None


def test_main_rejects_version_mismatch(monkeypatch, capsys):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v0.8.2\n", encoding="utf-8")
        plugins_dir = Path(directory) / "plugins"
        write_plugin_yaml(plugins_dir, "helm-unittest.git", name="unittest", version="1.1.2")

        monkeypatch.setattr(guard, "PIN_FILE", pin_file)
        monkeypatch.setattr(guard, "resolve_plugins_dir", lambda: plugins_dir)

        exit_code = guard.main()
        output = capsys.readouterr()

        assert exit_code == 1
        assert "0.8.2" in output.err
        assert "1.1.2" in output.err


def test_main_accepts_matching_version(monkeypatch, capsys):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v0.8.2\n", encoding="utf-8")
        plugins_dir = Path(directory) / "plugins"
        write_plugin_yaml(plugins_dir, "helm-unittest.git", name="unittest", version="0.8.2")

        monkeypatch.setattr(guard, "PIN_FILE", pin_file)
        monkeypatch.setattr(guard, "resolve_plugins_dir", lambda: plugins_dir)

        exit_code = guard.main()

        assert exit_code == 0


def test_main_fails_closed_on_missing_pin_file(monkeypatch):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        monkeypatch.setattr(guard, "PIN_FILE", Path(directory) / "does-not-exist")

        assert guard.main() == 1


def test_main_fails_closed_on_missing_plugin(monkeypatch):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v0.8.2\n", encoding="utf-8")

        monkeypatch.setattr(guard, "PIN_FILE", pin_file)
        monkeypatch.setattr(guard, "resolve_plugins_dir", lambda: Path(directory) / "empty-plugins")

        assert guard.main() == 1
