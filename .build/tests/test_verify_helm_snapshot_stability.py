from __future__ import annotations

import importlib.util
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


def test_main_capture_then_verify_round_trip(capsys):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        snapshot_dir = Path(directory) / "__snapshot__"
        snapshot_dir.mkdir()
        (snapshot_dir / "celery_test.yaml.snap").write_text("'disabled: celery':\n", encoding="utf-8")
        guard.SNAPSHOT_DIR = snapshot_dir

        hashfile = Path(directory) / "hashes.txt"

        assert guard.main(["capture", str(hashfile)]) == 0
        assert guard.main(["verify", str(hashfile)]) == 0


def test_main_verify_fails_closed_on_missing_hashfile(capsys):
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        exit_code = guard.main(["verify", str(Path(directory) / "does-not-exist.txt")])
        output = capsys.readouterr()

        assert exit_code == 1
        assert "missing captured hashfile" in output.err


def test_main_rejects_unknown_command():
    guard = load_guard()
    assert guard.main(["bogus", "x"]) == 2
