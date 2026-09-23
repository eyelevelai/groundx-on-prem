from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
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


@contextlib.contextmanager
def captured_stderr():
    buffer = io.StringIO()
    with contextlib.redirect_stderr(buffer):
        yield buffer


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


def test_main_rejects_version_mismatch():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v0.8.2\n", encoding="utf-8")
        plugins_dir = Path(directory) / "plugins"
        write_plugin_yaml(plugins_dir, "helm-unittest.git", name="unittest", version="1.1.2")

        guard.PIN_FILE = pin_file
        guard.resolve_plugins_dir = lambda: plugins_dir

        with captured_stderr() as buffer:
            exit_code = guard.main()

        text = buffer.getvalue()

        assert exit_code == 1
        assert "0.8.2" in text
        assert "1.1.2" in text


def test_main_accepts_matching_version():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v0.8.2\n", encoding="utf-8")
        plugins_dir = Path(directory) / "plugins"
        write_plugin_yaml(plugins_dir, "helm-unittest.git", name="unittest", version="0.8.2")

        guard.PIN_FILE = pin_file
        guard.resolve_plugins_dir = lambda: plugins_dir
        guard.verify_binary_integrity = lambda *args, **kwargs: None

        exit_code = guard.main()

        assert exit_code == 0


def test_main_fails_closed_on_missing_pin_file():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        guard.PIN_FILE = Path(directory) / "does-not-exist"

        assert guard.main() == 1


def test_main_fails_closed_on_missing_plugin():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v0.8.2\n", encoding="utf-8")

        guard.PIN_FILE = pin_file
        guard.resolve_plugins_dir = lambda: Path(directory) / "empty-plugins"

        assert guard.main() == 1


def test_resolve_os_maps_known_platform_names():
    guard = load_guard()

    guard.platform.system = lambda: "Windows"
    assert guard.resolve_os() == "windows"

    guard.platform.system = lambda: "MINGW64_NT-10.0"
    assert guard.resolve_os() == "windows"

    guard.platform.system = lambda: "Darwin"
    assert guard.resolve_os() == "macos"

    guard.platform.system = lambda: "Linux"
    assert guard.resolve_os() == "linux"


def test_resolve_arch_maps_known_architecture_names():
    guard = load_guard()

    guard.platform.machine = lambda: "AMD64"
    assert guard.resolve_arch() == "amd64"

    guard.platform.machine = lambda: "x86_64"
    assert guard.resolve_arch() == "amd64"

    guard.platform.machine = lambda: "aarch64"
    assert guard.resolve_arch() == "arm64"

    guard.platform.machine = lambda: "armv7l"
    assert guard.resolve_arch() == "armv7"


def test_binary_file_name_appends_exe_suffix_on_windows_only():
    guard = load_guard()

    assert guard.binary_file_name("windows", "amd64") == "untt-windows-amd64.exe"
    assert guard.binary_file_name("linux", "amd64") == "untt-linux-amd64"
    assert guard.binary_file_name("macos", "arm64") == "untt-macos-arm64"


def test_verify_binary_integrity_accepts_matching_bytes():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        binary_bytes = b"pinned-release-binary-contents"
        (plugin_dir / "untt-linux-amd64").write_bytes(binary_bytes)

        guard.fetch_pinned_binary_bytes = lambda *args, **kwargs: binary_bytes

        guard.verify_binary_integrity(plugin_dir, "v1.1.2", "linux", "amd64")


def test_verify_binary_integrity_rejects_mismatched_bytes():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        (plugin_dir / "untt-linux-amd64").write_bytes(b"stale-local-binary")

        guard.fetch_pinned_binary_bytes = lambda *args, **kwargs: b"real-pinned-release-binary"

        try:
            guard.verify_binary_integrity(plugin_dir, "v1.1.2", "linux", "amd64")
        except guard.BinaryVerificationError as exc:
            message = str(exc)
            assert hashlib.sha256(b"stale-local-binary").hexdigest() in message
            assert hashlib.sha256(b"real-pinned-release-binary").hexdigest() in message
        else:
            raise AssertionError("expected BinaryVerificationError for a byte mismatch")


def test_verify_binary_integrity_fails_closed_when_local_binary_missing():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)

        guard.fetch_pinned_binary_bytes = lambda *args, **kwargs: b"irrelevant"

        try:
            guard.verify_binary_integrity(plugin_dir, "v1.1.2", "linux", "amd64")
        except guard.BinaryVerificationError:
            pass
        else:
            raise AssertionError("expected BinaryVerificationError for a missing local binary")


def test_verify_binary_integrity_fails_closed_when_fetch_raises():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        (plugin_dir / "untt-linux-amd64").write_bytes(b"local-binary")

        def raise_fetch_error(*args, **kwargs):
            raise guard.BinaryVerificationError("simulated network failure")

        guard.fetch_pinned_binary_bytes = raise_fetch_error

        try:
            guard.verify_binary_integrity(plugin_dir, "v1.1.2", "linux", "amd64")
        except guard.BinaryVerificationError as exc:
            assert "simulated network failure" in str(exc)
        else:
            raise AssertionError("expected BinaryVerificationError when the fetch step fails")


def test_fetch_pinned_binary_bytes_fails_closed_on_download_error():
    guard = load_guard()

    class FailingOpener:
        def __call__(self, *args, **kwargs):
            raise guard.urllib.error.URLError("simulated download failure")

    guard.urllib.request.urlopen = FailingOpener()

    try:
        guard.fetch_pinned_binary_bytes("1.1.2", "linux", "amd64", "untt-linux-amd64")
    except guard.BinaryVerificationError as exc:
        assert "failed to download" in str(exc)
    else:
        raise AssertionError("expected BinaryVerificationError when the download fails")


def test_fetch_pinned_binary_bytes_fails_closed_on_malformed_archive():
    guard = load_guard()

    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, *exc_info):
            return False

        def read(self):
            return b"not-a-valid-gzip-archive"

    guard.urllib.request.urlopen = lambda *args, **kwargs: FakeResponse()

    try:
        guard.fetch_pinned_binary_bytes("1.1.2", "linux", "amd64", "untt-linux-amd64")
    except guard.BinaryVerificationError as exc:
        assert "failed to read" in str(exc)
    else:
        raise AssertionError("expected BinaryVerificationError for a malformed archive")


def test_main_fails_closed_when_binary_verification_fails():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        pin_file = Path(directory) / "HELM_UNITTEST_VERSION"
        pin_file.write_text("v1.1.2\n", encoding="utf-8")
        plugins_dir = Path(directory) / "plugins"
        write_plugin_yaml(plugins_dir, "helm-unittest.git", name="unittest", version="1.1.2")

        guard.PIN_FILE = pin_file
        guard.resolve_plugins_dir = lambda: plugins_dir

        def raise_binary_error(*args, **kwargs):
            raise guard.BinaryVerificationError("simulated binary mismatch")

        guard.verify_binary_integrity = raise_binary_error

        with captured_stderr() as buffer:
            exit_code = guard.main()

        assert exit_code == 1
        assert "simulated binary mismatch" in buffer.getvalue()


def main() -> int:
    test_pinned_version_reads_and_strips_whitespace()
    test_installed_version_finds_matching_plugin_by_name()
    test_installed_version_ignores_unrelated_plugin_directories()
    test_installed_version_returns_none_when_plugins_dir_missing()
    test_main_rejects_version_mismatch()
    test_main_accepts_matching_version()
    test_main_fails_closed_on_missing_pin_file()
    test_main_fails_closed_on_missing_plugin()
    test_resolve_os_maps_known_platform_names()
    test_resolve_arch_maps_known_architecture_names()
    test_binary_file_name_appends_exe_suffix_on_windows_only()
    test_verify_binary_integrity_accepts_matching_bytes()
    test_verify_binary_integrity_rejects_mismatched_bytes()
    test_verify_binary_integrity_fails_closed_when_local_binary_missing()
    test_verify_binary_integrity_fails_closed_when_fetch_raises()
    test_fetch_pinned_binary_bytes_fails_closed_on_download_error()
    test_fetch_pinned_binary_bytes_fails_closed_on_malformed_archive()
    test_main_fails_closed_when_binary_verification_fails()
    print("verify-helm-unittest-plugin-version tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
