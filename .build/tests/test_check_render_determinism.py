from __future__ import annotations

import contextlib
import importlib.util
import io
import os
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


@contextlib.contextmanager
def env_vars(**values: str):
    previous = {key: os.environ.get(key) for key in values}
    os.environ.update(values)
    try:
        yield
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def test_identical_renders_pass():
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_STABLE)
        with env_vars(HELM_BIN=f"{sys.executable} {script}"):
            diff = checker.render_and_diff(chart=Path("src/groundx"), values=[], root=Path(directory), focus=None)

        assert diff == []


def test_differing_renders_are_detected_and_fail_in_blocking_mode():
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_FLAKY)
        counter_file = Path(directory) / "counter.txt"
        with env_vars(HELM_BIN=f"{sys.executable} {script}", FAKE_HELM_COUNTER_FILE=str(counter_file)):
            diff = checker.render_and_diff(chart=Path("src/groundx"), values=[], root=Path(directory), focus=None)

            assert diff != []

            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                exit_code = checker.main(["--chart", "src/groundx", "--root", directory])

        assert exit_code == 1


def test_differing_renders_warn_only_exits_zero_with_flip_condition_message():
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_FLAKY)
        counter_file = Path(directory) / "counter.txt"
        with env_vars(HELM_BIN=f"{sys.executable} {script}", FAKE_HELM_COUNTER_FILE=str(counter_file)):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                exit_code = checker.main(["--chart", "src/groundx", "--root", directory, "--warn-only"])

        text = output.getvalue()

        assert exit_code == 0
        assert "warn-only" in text
        assert "GX-22" in text
        assert "permanently" in text
        assert "chart-helper fix" not in text
        assert "remove --warn-only" not in text


def test_focus_pattern_ignores_unrelated_drift():
    checker = load_checker()
    with tempfile.TemporaryDirectory() as directory:
        script = write_fake_helm(Path(directory), FAKE_HELM_FLAKY)
        counter_file = Path(directory) / "counter.txt"
        with env_vars(HELM_BIN=f"{sys.executable} {script}", FAKE_HELM_COUNTER_FILE=str(counter_file)):
            diff = checker.render_and_diff(
                chart=Path("src/groundx"),
                values=[],
                root=Path(directory),
                focus="layout-ocr-does-not-appear-in-fake-output",
            )

        assert diff == []


def main() -> int:
    test_identical_renders_pass()
    test_differing_renders_are_detected_and_fail_in_blocking_mode()
    test_differing_renders_warn_only_exits_zero_with_flip_condition_message()
    test_focus_pattern_ignores_unrelated_drift()
    print("check-render-determinism tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
