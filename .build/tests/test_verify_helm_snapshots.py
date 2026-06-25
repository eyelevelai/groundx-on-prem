from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path


def load_guard():
    path = Path(__file__).resolve().parents[1] / "bin" / "verify-helm-snapshots.py"
    spec = importlib.util.spec_from_file_location("verify_helm_snapshots", path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_required_empty_snapshot_labels_must_still_be_empty():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        test_dir = Path(directory) / "tests"
        snapshot_dir = test_dir / "__snapshot__"
        snapshot_dir.mkdir(parents=True)

        (test_dir / "cache_test.yaml").write_text(
            """
suite: caches render as expected
tests:
  - it: "cache-persistence: cache"
    asserts:
      - matchSnapshot: {}
""",
            encoding="utf-8",
        )
        (snapshot_dir / "cache_test.yaml.snap").write_text(
            """
'cache-persistence: cache':
  1: |
    apiVersion: v1
""",
            encoding="utf-8",
        )

        failures = guard.verify_snapshot_labels(
            test_dir=test_dir,
            snapshot_dir=snapshot_dir,
            required_empty_labels={"cache_test.yaml.snap": {"aws: cache"}},
            diff_output="",
        )

        assert failures == [
            "src/groundx/tests/__snapshot__/cache_test.yaml.snap required empty snapshot labels missing or rendered: aws: cache"
        ]


def test_required_empty_snapshot_labels_accept_legacy_label_only_shape():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        test_dir = Path(directory) / "tests"
        snapshot_dir = test_dir / "__snapshot__"
        snapshot_dir.mkdir(parents=True)

        (test_dir / "cache_test.yaml").write_text(
            """
suite: caches render as expected
tests:
  - it: "aws: cache"
    asserts:
      - matchSnapshot: {}
  - it: "cache-persistence: cache"
    asserts:
      - matchSnapshot: {}
""",
            encoding="utf-8",
        )
        (snapshot_dir / "cache_test.yaml.snap").write_text(
            """
'aws: cache':
'cache-persistence: cache':
  1: |
    apiVersion: v1
""",
            encoding="utf-8",
        )

        failures = guard.verify_snapshot_labels(
            test_dir=test_dir,
            snapshot_dir=snapshot_dir,
            required_empty_labels={"cache_test.yaml.snap": {"aws: cache"}},
            diff_output="",
        )

        assert failures == []


def test_empty_snapshot_labels_reject_braces_and_spacer_lines():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        test_dir = Path(directory) / "tests"
        snapshot_dir = test_dir / "__snapshot__"
        snapshot_dir.mkdir(parents=True)

        (test_dir / "cache_test.yaml").write_text(
            """
suite: caches render as expected
tests:
  - it: "aws: cache"
    asserts:
      - matchSnapshot: {}
  - it: "existing: cache"
    asserts:
      - matchSnapshot: {}
  - it: "cache-persistence: cache"
    asserts:
      - matchSnapshot: {}
  - it: "metadata: cache"
    asserts:
      - matchSnapshot: {}
""",
            encoding="utf-8",
        )
        (snapshot_dir / "cache_test.yaml.snap").write_text(
            """
'aws: cache': {}

'cache-persistence: cache':
  1: |
    apiVersion: v1
'existing: cache':

'metadata: cache':
  1: |
    apiVersion: v1
""",
            encoding="utf-8",
        )

        failures = guard.verify_snapshot_labels(
            test_dir=test_dir,
            snapshot_dir=snapshot_dir,
            required_empty_labels={"cache_test.yaml.snap": {"aws: cache", "existing: cache"}},
            diff_output="",
        )

        assert failures == [
            "src/groundx/tests/__snapshot__/cache_test.yaml.snap empty snapshot labels must use label-only shape without spacer lines: aws: cache, existing: cache"
        ]


def test_deleted_snapshot_labels_from_diff_catches_block_label_deletion():
    guard = load_guard()
    diff = """
diff --git a/src/groundx/tests/__snapshot__/cache_test.yaml.snap b/src/groundx/tests/__snapshot__/cache_test.yaml.snap
--- a/src/groundx/tests/__snapshot__/cache_test.yaml.snap
+++ b/src/groundx/tests/__snapshot__/cache_test.yaml.snap
@@ -1,4 +1,201 @@
-'aws: cache':
+'cache-persistence: cache':
   1: |
     apiVersion: apps/v1
"""

    assert guard.deleted_snapshot_labels_from_diff(diff) == [
        "src/groundx/tests/__snapshot__/cache_test.yaml.snap: 'aws: cache'"
    ]


def test_deleted_snapshot_labels_from_diff_ignores_moved_labels():
    guard = load_guard()
    diff = """
diff --git a/src/groundx/tests/__snapshot__/cache_test.yaml.snap b/src/groundx/tests/__snapshot__/cache_test.yaml.snap
--- a/src/groundx/tests/__snapshot__/cache_test.yaml.snap
+++ b/src/groundx/tests/__snapshot__/cache_test.yaml.snap
@@ -1,3 +1,5 @@
+'aws: cache': {}
+
 'cache-persistence: cache':
@@ -100,5 +102,3 @@
-'aws: cache': {}
-
 'workspace-enabled: cache': {}
"""

    assert guard.deleted_snapshot_labels_from_diff(diff) == []


def test_snapshot_labels_must_be_sorted_by_case_then_surface():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        test_dir = Path(directory) / "tests"
        snapshot_dir = test_dir / "__snapshot__"
        snapshot_dir.mkdir(parents=True)

        (test_dir / "api_test.yaml").write_text(
            """
suite: api renders as expected
tests:
  - it: "extract: api"
    asserts:
      - matchSnapshot: {}
  - it: "extract.ingest: api"
    asserts:
      - matchSnapshot: {}
""",
            encoding="utf-8",
        )
        (snapshot_dir / "api_test.yaml.snap").write_text(
            """
'extract.ingest: api':
  1: |
    kind: Service
'extract: api':
  1: |
    kind: Service
""",
            encoding="utf-8",
        )

        failures = guard.verify_snapshot_labels(
            test_dir=test_dir,
            snapshot_dir=snapshot_dir,
            required_empty_labels={},
            diff_output="",
        )

        assert failures == [
            "src/groundx/tests/__snapshot__/api_test.yaml.snap snapshot labels must be sorted: extract.ingest: api before extract: api"
        ]


def main() -> int:
    test_required_empty_snapshot_labels_must_still_be_empty()
    test_required_empty_snapshot_labels_accept_legacy_label_only_shape()
    test_empty_snapshot_labels_reject_braces_and_spacer_lines()
    test_deleted_snapshot_labels_from_diff_catches_block_label_deletion()
    test_deleted_snapshot_labels_from_diff_ignores_moved_labels()
    test_snapshot_labels_must_be_sorted_by_case_then_surface()
    print("verify-helm-snapshots tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
