#!/usr/bin/env python3
"""Check rendered private extraction configuration against the installed SDK.

Run with a Python environment containing GroundX and PyYAML. Old SDKs must
reject private configuration before Upload initialization. Compatible SDKs
must retain the endpoint and private bucket setting. No network or storage
operation is performed.
"""

from pathlib import Path
import subprocess
from unittest.mock import patch

import yaml
from groundx.extract import ContainerUploadSettings


ROOT = Path(__file__).resolve().parents[2]
ERROR = "private extraction storage requires a compatible GroundX SDK"


def config_source(chart: str, *, private: bool) -> str:
    command = ["helm", "template", "sdk-admission", chart, "-f", "src/groundx/tests/files/values.search-credentials.yaml", "--set", "extract.enabled=true"]
    if private:
        command.extend(["-f", "src/groundx/tests/files/values.file-access.yaml"])
    completed = subprocess.run(command, cwd=ROOT, check=True, capture_output=True, text=True)
    for document in yaml.safe_load_all(completed.stdout):
        if isinstance(document, dict) and document.get("metadata", {}).get("name") == "extract-config-py-map":
            return document["stringData"]["config.py"]
    raise AssertionError("rendered extraction config is missing")


def main() -> None:
    compatible = {"public_read", "storage_endpoint"}.issubset(ContainerUploadSettings.model_fields)
    for chart in ("src/groundx", "helm"):
        public = config_source(chart, private=False)
        assert ERROR not in public
        exec(compile(public, "public-config.py", "exec"), {})
        source = config_source(chart, private=True)
        namespace = {}
        initialized = []

        def initialize(*_args, **_kwargs):
            initialized.append(True)
            raise AssertionError("admission test must never initialize storage")

        with patch("groundx.extract.Upload", initialize):
            try:
                exec(compile(source, "private-config.py", "exec"), namespace)
            except RuntimeError as error:
                assert not compatible and str(error) == ERROR
            else:
                assert compatible, "old SDK accepted private storage settings"
                settings = namespace["container_settings"].upload
                assert settings.public_read is False
                assert settings.storage_endpoint == "https://store.internal.example.com:9443"
        assert not initialized
    print("private extraction SDK admission passed: " + ("compatible" if compatible else "unsupported SDK rejected"))


if __name__ == "__main__":
    main()
