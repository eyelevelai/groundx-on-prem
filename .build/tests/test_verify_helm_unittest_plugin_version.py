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


def write_reference_hashes(directory: Path, entries: dict[str, str]) -> Path:
    reference_file = directory / "HELM_UNITTEST_BINARY_SHA256"
    lines = [f"{platform_key}  {digest}" for platform_key, digest in entries.items()]
    reference_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return reference_file


def test_read_reference_hashes_parses_platform_lines():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        reference_file = write_reference_hashes(
            Path(directory), {"linux-amd64": "a" * 64, "macos-arm64": "b" * 64}
        )

        hashes = guard.read_reference_hashes(reference_file)

        assert hashes == {"linux-amd64": "a" * 64, "macos-arm64": "b" * 64}


def test_read_reference_hashes_skips_comment_and_blank_lines():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        reference_file = Path(directory) / "HELM_UNITTEST_BINARY_SHA256"
        reference_file.write_text(
            "# SHA-256 reference hashes — see header for provenance\n"
            "\n"
            f"linux-amd64  {'a' * 64}\n"
            "# a mid-file comment line should also be skipped\n"
            f"macos-arm64  {'b' * 64}\n",
            encoding="utf-8",
        )

        hashes = guard.read_reference_hashes(reference_file)

        assert hashes == {"linux-amd64": "a" * 64, "macos-arm64": "b" * 64}


def test_verify_binary_integrity_accepts_matching_bytes():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        binary_bytes = b"pinned-release-binary-contents"
        (plugin_dir / "untt-linux-amd64").write_bytes(binary_bytes)
        digest = hashlib.sha256(binary_bytes).hexdigest()
        reference_file = write_reference_hashes(plugin_dir, {"linux-amd64": digest})

        guard.verify_binary_integrity(plugin_dir, "linux", "amd64", reference_file)


def test_verify_binary_integrity_rejects_mismatched_bytes():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        (plugin_dir / "untt-linux-amd64").write_bytes(b"stale-local-binary")
        real_digest = hashlib.sha256(b"real-pinned-release-binary").hexdigest()
        reference_file = write_reference_hashes(plugin_dir, {"linux-amd64": real_digest})

        try:
            guard.verify_binary_integrity(plugin_dir, "linux", "amd64", reference_file)
        except guard.BinaryVerificationError as exc:
            message = str(exc)
            assert hashlib.sha256(b"stale-local-binary").hexdigest() in message
            assert real_digest in message
        else:
            raise AssertionError("expected BinaryVerificationError for a byte mismatch")


def test_verify_binary_integrity_fails_closed_when_local_binary_missing():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        reference_file = write_reference_hashes(plugin_dir, {"linux-amd64": "c" * 64})

        try:
            guard.verify_binary_integrity(plugin_dir, "linux", "amd64", reference_file)
        except guard.BinaryVerificationError:
            pass
        else:
            raise AssertionError("expected BinaryVerificationError for a missing local binary")


def test_verify_binary_integrity_fails_closed_when_reference_file_missing():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        (plugin_dir / "untt-linux-amd64").write_bytes(b"local-binary")
        reference_file = plugin_dir / "does-not-exist"

        try:
            guard.verify_binary_integrity(plugin_dir, "linux", "amd64", reference_file)
        except guard.BinaryVerificationError as exc:
            assert "missing reference hash file" in str(exc)
        else:
            raise AssertionError("expected BinaryVerificationError when the reference file is missing")


def test_verify_binary_integrity_fails_closed_when_platform_entry_missing():
    guard = load_guard()
    with tempfile.TemporaryDirectory() as directory:
        plugin_dir = Path(directory)
        (plugin_dir / "untt-linux-amd64").write_bytes(b"local-binary")
        reference_file = write_reference_hashes(plugin_dir, {"macos-arm64": "d" * 64})

        try:
            guard.verify_binary_integrity(plugin_dir, "linux", "amd64", reference_file)
        except guard.BinaryVerificationError as exc:
            assert "no reference sha256 entry for platform 'linux-amd64'" in str(exc)
        else:
            raise AssertionError("expected BinaryVerificationError for a missing platform entry")


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
    test_read_reference_hashes_parses_platform_lines()
    test_read_reference_hashes_skips_comment_and_blank_lines()
    test_verify_binary_integrity_accepts_matching_bytes()
    test_verify_binary_integrity_rejects_mismatched_bytes()
    test_verify_binary_integrity_fails_closed_when_local_binary_missing()
    test_verify_binary_integrity_fails_closed_when_reference_file_missing()
    test_verify_binary_integrity_fails_closed_when_platform_entry_missing()
    test_main_fails_closed_when_binary_verification_fails()
    print("verify-helm-unittest-plugin-version tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
