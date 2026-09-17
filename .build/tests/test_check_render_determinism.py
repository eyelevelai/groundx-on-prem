from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path


def load_checker():
    path = Path(__file__).resolve().parents[1] / "bin" / "check-render-determinism.py"
    spec = importlib.util.spec_from_file_location("check_render_determinism", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


FAKE_HELM_STABLE = """
import sys
print("replicas: 1")
"""

FAKE_HELM_FLAKY = """
import os
import sys

counter_file = os.environ["FAKE_HELM_COUNTER_FILE"]
count = 0
if os.path.exists(counter_file):
    count = int(open(counter_file, encoding="utf-8").read())
count += 1
with open(counter_file, "w", encoding="utf-8") as handle:
    handle.write(str(count))
print(f"replicas: {count}")
"""


def write_fake_helm(directory: Path, body: str) -> Path:
    script = directory / "fake_helm.py"
    script.write_text(body, encoding="utf-8")
    return script


def test_identical_renders_pass(monkeypatch):
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_STABLE)
        monkeypatch.setenv("HELM_BIN", f"{sys.executable} {script}")

        diff = checker.render_and_diff(chart=Path("src/groundx"), values=[], root=Path(directory), focus=None)

        assert diff == []


def test_differing_renders_are_detected_and_fail_in_blocking_mode(monkeypatch, capsys):
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_FLAKY)
        counter_file = Path(directory) / "counter.txt"
        monkeypatch.setenv("HELM_BIN", f"{sys.executable} {script}")
        monkeypatch.setenv("FAKE_HELM_COUNTER_FILE", str(counter_file))

        diff = checker.render_and_diff(chart=Path("src/groundx"), values=[], root=Path(directory), focus=None)

        assert diff != []

        exit_code = checker.main(["--chart", "src/groundx", "--root", directory])

        assert exit_code == 1


def test_differing_renders_warn_only_exits_zero_with_flip_condition_message(monkeypatch, capsys):
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_FLAKY)
        counter_file = Path(directory) / "counter.txt"
        monkeypatch.setenv("HELM_BIN", f"{sys.executable} {script}")
        monkeypatch.setenv("FAKE_HELM_COUNTER_FILE", str(counter_file))

        exit_code = checker.main(["--chart", "src/groundx", "--root", directory, "--warn-only"])
        output = capsys.readouterr()

        assert exit_code == 0
        assert "warn-only" in output.out
        assert "GX-22" in output.out
        assert "permanently" in output.out
        assert "chart-helper fix" not in output.out
        assert "remove --warn-only" not in output.out


def test_focus_pattern_ignores_unrelated_drift(monkeypatch):
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_FLAKY)
        counter_file = Path(directory) / "counter.txt"
        monkeypatch.setenv("HELM_BIN", f"{sys.executable} {script}")
        monkeypatch.setenv("FAKE_HELM_COUNTER_FILE", str(counter_file))

        diff = checker.render_and_diff(
            chart=Path("src/groundx"),
            values=[],
            root=Path(directory),
            focus="layout-ocr-does-not-appear-in-fake-output",
        )

        assert diff == []
