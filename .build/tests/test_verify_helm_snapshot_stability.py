from __future__ import annotations

import contextlib
import importlib.util
import io
import tempfile
from pathlib import Path


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-helm-snapshot-stability.py"
    spec = importlib.util.spec_from_file_location("verify_helm_snapshot_stability", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@contextlib.contextmanager
def captured_stderr():
    buffer = io.StringIO()
    with contextlib.redirect_stderr(buffer):
        yield buffer


def test_unchanged_snapshot_tree_is_not_flagged():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        (snapshot_dir / "celery_test.yaml.snap").write_text("'disabled: celery':\n", encoding="utf-8")

        hashfile = Path(directory) / "hashes.txt"
        guard.capture(snapshot_dir, hashfile)

        assert guard.verify(snapshot_dir, hashfile) == []


def test_snapshot_mutated_between_capture_and_verify_is_rejected():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        snap_file = snapshot_dir / "celery_test.yaml.snap"
        snap_file.write_text("'disabled: celery':\n", encoding="utf-8")

        hashfile = Path(directory) / "hashes.txt"
        guard.capture(snapshot_dir, hashfile)

        snap_file.write_text("'disabled: celery': {}\n", encoding="utf-8")

        changed = guard.verify(snapshot_dir, hashfile)

        assert changed == ["celery_test.yaml.snap"]


def test_baseline_already_differing_from_git_head_is_not_flagged():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        snap_file = snapshot_dir / "celery_test.yaml.snap"
        snap_file.write_text("'disabled: celery': UNCOMMITTED-EDIT\n", encoding="utf-8")

        hashfile = Path(directory) / "hashes.txt"
        guard.capture(snapshot_dir, hashfile)

        changed = guard.verify(snapshot_dir, hashfile)

        assert changed == []


def test_verify_names_every_changed_file():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        (snapshot_dir / "a_test.yaml.snap").write_text("a: 1\n", encoding="utf-8")
        (snapshot_dir / "b_test.yaml.snap").write_text("b: 1\n", encoding="utf-8")

        hashfile = Path(directory) / "hashes.txt"
        guard.capture(snapshot_dir, hashfile)

        (snapshot_dir / "a_test.yaml.snap").write_text("a: 2\n", encoding="utf-8")
        (snapshot_dir / "b_test.yaml.snap").write_text("b: 2\n", encoding="utf-8")

        assert guard.verify(snapshot_dir, hashfile) == ["a_test.yaml.snap", "b_test.yaml.snap"]


def test_main_capture_then_verify_round_trip():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        (snapshot_dir / "celery_test.yaml.snap").write_text("'disabled: celery':\n", encoding="utf-8")
        guard.SNAPSHOT_DIR = snapshot_dir

        hashfile = Path(directory) / "hashes.txt"

        assert guard.main(["capture", str(hashfile)]) == 0
        assert guard.main(["verify", str(hashfile)]) == 0


def test_main_verify_fails_closed_on_missing_hashfile():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        with captured_stderr() as buffer:
            exit_code = guard.main(["verify", str(Path(directory) / "does-not-exist.txt")])

        assert exit_code == 1
        assert "missing captured hashfile" in buffer.getvalue()


def test_main_rejects_unknown_command():
    guard = load_guard()
    assert guard.main(["bogus", "x"]) == 2


def test_capture_fails_closed_when_snapshot_dir_missing():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "does-not-exist"
        hashfile = Path(directory) / "hashes.txt"

        try:
            guard.capture(snapshot_dir, hashfile)
            raised = False
        except FileNotFoundError:
            raised = True

        assert raised
        assert not hashfile.exists()


def test_capture_fails_closed_when_snapshot_dir_empty():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        hashfile = Path(directory) / "hashes.txt"

        try:
            guard.capture(snapshot_dir, hashfile)
            raised = False
        except ValueError:
            raised = True

        assert raised
        assert not hashfile.exists()


def test_main_capture_fails_closed_on_missing_snapshot_dir():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        guard.SNAPSHOT_DIR = Path(directory) / "does-not-exist"
        hashfile = Path(directory) / "hashes.txt"

        with captured_stderr() as buffer:
            exit_code = guard.main(["capture", str(hashfile)])

        assert exit_code == 1
        assert "snapshot directory not found" in buffer.getvalue()
        assert not hashfile.exists()


def test_main_verify_fails_closed_when_tree_vanishes_after_capture():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        (snapshot_dir / "celery_test.yaml.snap").write_text("'disabled: celery':\n", encoding="utf-8")
        guard.SNAPSHOT_DIR = snapshot_dir

        hashfile = Path(directory) / "hashes.txt"
        assert guard.main(["capture", str(hashfile)]) == 0

        for entry in sorted(snapshot_dir.iterdir(), reverse=True):
            entry.unlink()
        snapshot_dir.rmdir()

        with captured_stderr() as buffer:
            exit_code = guard.main(["verify", str(hashfile)])

        assert exit_code == 1
        text = buffer.getvalue()
        assert "snapshot directory not found" in text
        assert "vanished" in text


def main() -> int:
    test_unchanged_snapshot_tree_is_not_flagged()
    test_snapshot_mutated_between_capture_and_verify_is_rejected()
    test_baseline_already_differing_from_git_head_is_not_flagged()
    test_verify_names_every_changed_file()
    test_main_capture_then_verify_round_trip()
    test_main_verify_fails_closed_on_missing_hashfile()
    test_main_rejects_unknown_command()
    test_capture_fails_closed_when_snapshot_dir_missing()
    test_capture_fails_closed_when_snapshot_dir_empty()
    test_main_capture_fails_closed_on_missing_snapshot_dir()
    test_main_verify_fails_closed_when_tree_vanishes_after_capture()
    print("verify-helm-snapshot-stability tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
