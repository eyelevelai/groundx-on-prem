#!/usr/bin/env python3
"""Verify persistent storage chart and generated AWS install contracts."""

from __future__ import annotations

import filecmp
import re
import subprocess
import sys
import tempfile
import typing
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHART = ROOT / "src" / "groundx"
CHARTS = (ROOT / "src" / "groundx", ROOT / "helm")
STORAGE_CHART = ROOT / "src" / "groundx" / "prereqs" / "storageclass"
STORAGE_CHARTS = (
    ROOT / "src" / "groundx" / "prereqs" / "storageclass",
    ROOT / "helm" / "prereqs" / "storageclass",
)

SECRET_CHART = ROOT / "src" / "groundx" / "prereqs" / "secret"
EKS_VALUES = ROOT / "values.extract.eks.yaml"
EKS_SECRET_VALUES = ROOT / "values.extract.eks.secret.yaml"


class StorageExampleSpec(typing.TypedDict):
    file: typing.Optional[str]
    must: typing.Tuple[str, ...]
    must_not: typing.Tuple[str, ...]


class PvcFixtureRequiredSpec(typing.TypedDict):
    must: typing.Tuple[str, ...]


class PvcFixtureSpec(PvcFixtureRequiredSpec, total=False):
    values: typing.Tuple[str, ...]
    show_only: typing.Tuple[str, ...]


class GeneratedValuesSpec(typing.TypedDict):
    storage: str
    app: str
    storage_must: typing.Tuple[str, ...]
    storage_must_not: typing.Tuple[str, ...]
    access: str


StorageCheck = typing.Callable[[], typing.List[str]]


STORAGE_EXAMPLES: typing.Dict[str, StorageExampleSpec] = {
    "default": {
        "file": None,
        "must": (
            r"provisioner:\s+ebs\.csi\.aws\.com",
            r'reclaimPolicy:\s+Delete',
            r'type:\s+"gp3"',
        ),
        "must_not": (r'type:\s+""', r"parameters:\s+\{\}"),
    },
    "ebs": {
        "file": "values.ebs.example.yaml",
        "must": (
            r"provisioner:\s+ebs\.csi\.aws\.com",
            r'reclaimPolicy:\s+Delete',
            r'type:\s+"gp3"',
        ),
        "must_not": (r'type:\s+""', r"parameters:\s+\{\}"),
    },
    "efs": {
        "file": "values.efs.example.yaml",
        "must": (
            r"provisioner:\s+efs\.csi\.aws\.com",
            r'reclaimPolicy:\s+Retain',
            r'basePath:\s+"/eyelevel"',
            r'fileSystemId:\s+"fs-REPLACE_ME"',
            r'provisioningMode:\s+"efs-ap"',
        ),
        "must_not": (r'type:\s+""', r'type:\s+"gp3"', r"parameters:\s+\{\}"),
    },
    "azure-files": {
        "file": "values.azure-files.example.yaml",
        "must": (r"provisioner:\s+file\.csi\.azure\.com",),
        "must_not": (r'type:\s+""', r'type:\s+"gp3"', r"parameters:\s+\{\}"),
    },
    "gke-filestore": {
        "file": "values.gke-filestore.example.yaml",
        "must": (r"provisioner:\s+filestore\.csi\.storage\.gke\.io",),
        "must_not": (r'type:\s+""', r'type:\s+"gp3"', r"parameters:\s+\{\}"),
    },
}
PVC_FIXTURES: typing.Dict[str, PvcFixtureSpec] = {
    "default-rwx": {
        "values": (),
        "must": (
            r"storageClassName:\s+eyelevel-pv",
            r"- ReadWriteMany",
            r'name:\s+"layout-model"',
            r'name:\s+"ranker-model"',
            r'name:\s+"summary-model"',
        ),
    },
    "aws-rwo": {
        "values": ("src/groundx/tests/files/values.extract.ingest.yaml",),
        "must": (
            r"storageClassName:\s+ebs-gp3-rwo",
            r"- ReadWriteOnce",
            r'name:\s+"layout-model"',
            r'name:\s+"summary-model"',
        ),
    },
    "workspace-local-rwo": {
        "values": ("src/groundx/tests/files/values.workspace.enabled.yaml",),
        "must": (
            r"storageClassName:\s+local-path-rwo",
            r"- ReadWriteOnce",
            r'name:\s+"workspace-data"',
        ),
    },
    "cache-persistence-rwx": {
        "values": ("src/groundx/tests/files/values.cache.persistence.yaml",),
        "show_only": (
            "templates/services/cache.yaml",
            "templates/services/cache-metrics.yaml",
        ),
        "must": (
            r"volumeClaimTemplates:",
            r"storageClassName:\s+eyelevel-pv",
            r"- ReadWriteMany",
            r"storage:\s+8Gi",
            r"emptyDir:\s+\{\}",
        ),
    },
}
MIRRORED_FILES = (
    "prereqs/storageclass/Chart.yaml",
    "prereqs/storageclass/templates/storageclass.yaml",
    "prereqs/storageclass/values.yaml",
    "prereqs/storageclass/values.ebs.example.yaml",
    "prereqs/storageclass/values.efs.example.yaml",
    "prereqs/storageclass/values.azure-files.example.yaml",
    "prereqs/storageclass/values.gke-filestore.example.yaml",
    "templates/_helpers/app/layout-inference.tpl",
    "templates/_helpers/app/ranker-inference.tpl",
    "templates/_helpers/app/summary-inference.tpl",
    "templates/_helpers/app/workspace.tpl",
    "templates/_helpers/services/cache.tpl",
    "templates/services/cache.yaml",
    "templates/services/cache-metrics.yaml",
)
STALE_PATTERNS = (
    r"type:\s+\"\"",
    r"groundx-workspaces",
    r"parameters:\s+\{\}",
)


def run(command: typing.List[str]) -> str:
    result = subprocess.run(command, cwd=ROOT, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(command)} failed:\n{result.stderr}")
    return result.stdout


def require(text: str, pattern: str, label: str) -> None:
    if re.search(pattern, text, flags=re.MULTILINE) is None:
        raise AssertionError(f"missing {label}: {pattern}")


def reject(text: str, pattern: str, label: str) -> None:
    if re.search(pattern, text, flags=re.MULTILINE) is not None:
        raise AssertionError(f"unexpected {label}: {pattern}")


def verify_storageclass(chart: Path) -> typing.List[str]:
    successes: typing.List[str] = []
    for name, spec in STORAGE_EXAMPLES.items():
        command = ["helm", "template", f"storage-{name}", str(chart)]
        values_file = spec["file"]
        if values_file is not None:
            command.extend(("-f", str(chart / values_file)))
        rendered = run(command)

        require(rendered, r"kind:\s+StorageClass", f"{name} StorageClass")
        for pattern in spec["must"]:
            require(rendered, pattern, f"{name} StorageClass value")
        for pattern in spec["must_not"]:
            reject(rendered, pattern, f"{name} StorageClass stale value")

        successes.append(f"{chart.relative_to(ROOT)} {name} storageclass passed")
    return successes


def verify_pvc_fixture(chart: Path, name: str, spec: PvcFixtureSpec) -> str:
    command = ["helm", "template", f"pvc-{name}", str(chart)]
    for values in spec.get("values", ()):
        command.extend(("-f", str(ROOT / values)))
    for show_only in spec.get("show_only", ()):
        command.extend(("--show-only", show_only))

    rendered = run(command)
    for pattern in spec["must"]:
        require(rendered, pattern, f"{name} PVC render")
    return f"{chart.relative_to(ROOT)} {name} PVC fixture passed"


def verify_mirrors() -> typing.List[str]:
    successes: typing.List[str] = []
    for relative in MIRRORED_FILES:
        left = ROOT / "src" / "groundx" / relative
        right = ROOT / "helm" / relative
        if not left.exists() or not right.exists():
            raise AssertionError(f"missing mirrored file: {relative}")
        if not filecmp.cmp(left, right, shallow=False):
            raise AssertionError(f"mirrored file drift: {relative}")
        successes.append(f"mirror {relative} passed")
    return successes


def verify_no_stale_strings() -> typing.List[str]:
    files = [
        *(ROOT / "src" / "groundx" / "prereqs" / "storageclass").glob("values*.yaml"),
        *(ROOT / "helm" / "prereqs" / "storageclass").glob("values*.yaml"),
        ROOT / "README.md",
    ]
    for path in files:
        text = path.read_text(encoding="utf-8")
        for pattern in STALE_PATTERNS:
            reject(text, pattern, f"stale storage string in {path.relative_to(ROOT)}")
    return ["stale storage string scan passed"]


def verify_setup_eks() -> typing.List[str]:
    script = (ROOT / "terraform" / "aws" / "setup-eks").read_text(encoding="utf-8")
    required = (
        r'storage_options=\("efs - EFS shared filesystem \(recommended\)" "ebs - EBS block volumes"\)',
        r'choose_storage=\$\(prompt_menu "What AWS persistent storage should this EKS install use\?" "storage_options\[@\]"\)',
        r'STORAGE_DRIVER=\$\{STORAGE_DRIVER:-\}',
        r'selected_storage=\$\(prompt_input "menu" "\$choose_storage" "storage_options\[@\]" ""\)',
        r'STORAGE_DRIVER="\$\{selected_storage%% \*\}"',
        r'Invalid STORAGE_DRIVER \[\$STORAGE_DRIVER\]\. Use efs or ebs\.',
        r"storage driver:\s+\$STORAGE_DRIVER",
        r"output -raw storage_driver",
        r"output -raw storage_access_mode",
        r"output -raw efs_file_system_id",
        r"values\.aws\.local\.yaml",
        r"basePath: /eyelevel",
        r"type: gp3",
    )
    for pattern in required:
        require(script, pattern, "setup-eks generated values wiring")
    return ["setup-eks storage generation scan passed"]


GENERATED: typing.Dict[str, GeneratedValuesSpec] = {
    "efs": {
        "storage": """storageClassName: eyelevel-pv
isDefaultClass: false

provisioner: efs.csi.aws.com

reclaimPolicy: Retain
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-0123456789abcdef0
  directoryPerms: "700"
  basePath: /eyelevel
""",
        "app": """cluster:
  pvClass: eyelevel-pv
  pvAccessMode: ReadWriteMany

workspace:
  enabled: true
  existingSecret: eyelevel-secret-credentials
  pvc:
    name: workspace-data
    capacity: 50Gi
""",
        "storage_must": (
            r"provisioner:\s+efs\.csi\.aws\.com",
            r'fileSystemId:\s+"fs-0123456789abcdef0"',
            r'basePath:\s+"/eyelevel"',
        ),
        "storage_must_not": (r'type:\s+"gp3"', r'type:\s+""'),
        "access": "ReadWriteMany",
    },
    "ebs": {
        "storage": """storageClassName: eyelevel-pv
isDefaultClass: true

provisioner: ebs.csi.aws.com

reclaimPolicy: Delete
parameters:
  type: gp3
""",
        "app": """cluster:
  pvClass: eyelevel-pv
  pvAccessMode: ReadWriteOnce

workspace:
  enabled: true
  existingSecret: eyelevel-secret-credentials
  pvc:
    name: workspace-data
    capacity: 50Gi
""",
        "storage_must": (
            r"provisioner:\s+ebs\.csi\.aws\.com",
            r'type:\s+"gp3"',
        ),
        "storage_must_not": (r'type:\s+""',),
        "access": "ReadWriteOnce",
    },
}


def write_values(directory: Path, name: str, text: str) -> Path:
    path = directory / name
    path.write_text(text, encoding="utf-8")
    return path


def verify_driver(driver: str, spec: GeneratedValuesSpec) -> typing.List[str]:
    successes: typing.List[str] = []
    with tempfile.TemporaryDirectory(prefix=f"groundx-{driver}-values-") as temp:
        temp_dir = Path(temp)
        storage_values = write_values(temp_dir, "values.aws.local.storage.yaml", str(spec["storage"]))
        app_values = write_values(temp_dir, "values.aws.local.app.yaml", str(spec["app"]))

        if EKS_SECRET_VALUES.exists():
            secret_render = run(
                [
                    "helm",
                    "template",
                    f"aws-{driver}-secret",
                    str(SECRET_CHART),
                    "-f",
                    str(EKS_SECRET_VALUES),
                ]
            )
            verify_secret_render(secret_render, driver)
            successes.append(f"{driver} generated install flow secret command passed")

        storage_render = run(
            ["helm", "template", f"aws-{driver}-storage", str(STORAGE_CHART), "-f", str(storage_values)]
        )
        for pattern in spec["storage_must"]:
            require(storage_render, pattern, f"{driver} generated storage values")
        for pattern in spec["storage_must_not"]:
            reject(storage_render, pattern, f"{driver} generated storage values")
        successes.append(f"{driver} generated StorageClass values passed")

        app_render = run(["helm", "template", f"aws-{driver}-app", str(CHART), "-f", str(app_values)])
        verify_app_render(app_render, driver, spec["access"])
        successes.append(f"{driver} generated app values passed")

        if EKS_VALUES.exists():
            install_flow_render = run(
                [
                    "helm",
                    "template",
                    f"aws-{driver}-eks",
                    str(CHART),
                    "-f",
                    str(EKS_VALUES),
                    "-f",
                    str(app_values),
                ]
            )
            verify_install_flow_render(install_flow_render, driver, spec["access"])
            successes.append(f"{driver} generated install flow app command passed")

    return successes


def verify_secret_render(rendered: str, driver: str) -> None:
    require(rendered, r"kind:\s+Secret", f"{driver} generated secret prereq")
    require(rendered, r"name:\s+eyelevel-secret-credentials", f"{driver} generated secret prereq name")
    require(rendered, r"WORKSPACE_RUNNER_TOKEN:", f"{driver} generated secret runner token")


def verify_app_render(rendered: str, driver: str, access: str) -> None:
    require(rendered, r'name:\s+"workspace-data"', f"{driver} workspace PVC")
    require(rendered, r'name:\s+"layout-model"', f"{driver} layout PVC")
    require(rendered, r'name:\s+"ranker-model"', f"{driver} ranker PVC")
    require(rendered, r'name:\s+"summary-model"', f"{driver} summary PVC")
    require(rendered, r"storageClassName:\s+eyelevel-pv", f"{driver} PVC class")
    require(rendered, rf"- {access}", f"{driver} PVC access")


def verify_workspace_pvc(rendered: str, driver: str, access: str) -> None:
    require(rendered, r'name:\s+"workspace-data"', f"{driver} EKS workspace PVC")
    require(rendered, r"storageClassName:\s+eyelevel-pv", f"{driver} EKS workspace PVC class")
    require(rendered, rf"- {access}", f"{driver} EKS workspace PVC access")


def verify_install_flow_render(rendered: str, driver: str, access: str) -> None:
    verify_workspace_pvc(rendered, driver, access)
    require(rendered, r"kind:\s+Deployment", f"{driver} generated install flow deployments")
    require(rendered, r"^  name:\s+workspace-api$", f"{driver} generated install flow workspace API")
    require(rendered, r"^  name:\s+workspace-provision$", f"{driver} generated install flow provision worker")
    require(rendered, r"^  name:\s+workspace-workspace$", f"{driver} generated install flow workspace worker")
    require(rendered, r"^  name:\s+workspace-command$", f"{driver} generated install flow command worker")
    require(rendered, r"^  name:\s+workspace-publish$", f"{driver} generated install flow publish worker")
    require(rendered, r"^  name:\s+workspace-cleanup$", f"{driver} generated install flow cleanup worker")
    require(rendered, r"name:\s+WORKSPACE_RUNNER_BASE_URL", f"{driver} generated install flow Partner API URL env")
    require(
        rendered,
        r"value:\s+http://workspace-api\.eyelevel\.svc\.cluster\.local",
        f"{driver} generated install flow Partner API URL value",
    )
    reject(rendered, r"Additional property data is not allowed", f"{driver} generated install flow secret misuse")


def verify_setup_script_contract() -> typing.List[str]:
    script = (ROOT / "terraform" / "aws" / "setup-eks").read_text(encoding="utf-8")
    required = (
        r"src/groundx/prereqs/storageclass/values\.aws\.local\.yaml",
        r"src/groundx/values\.aws\.local\.yaml",
        r"helm upgrade --install groundx-secret",
        r"src/groundx/prereqs/secret",
        r"-f values\.extract\.eks\.secret\.yaml",
        r"helm upgrade --install groundx-storageclass",
        r"helm upgrade --install groundx src/groundx",
        r"-f values\.extract\.eks\.yaml",
        r"-f src/groundx/values\.aws\.local\.yaml",
    )
    for pattern in required:
        require(script, pattern, "setup-eks printed Helm command contract")
    reject(
        script,
        r"helm upgrade --install groundx src/groundx .*values\.extract\.eks\.secret\.yaml",
        "secret values passed to main chart",
    )
    return ["setup-eks Helm command contract passed"]



def main() -> int:
    failures: typing.List[str] = []
    successes: typing.List[str] = []

    checks: typing.Tuple[StorageCheck, ...] = (
        lambda: [item for chart in STORAGE_CHARTS for item in verify_storageclass(chart)],
        lambda: [item for chart in CHARTS for name, spec in PVC_FIXTURES.items() for item in [verify_pvc_fixture(chart, name, spec)]],
        verify_mirrors,
        verify_no_stale_strings,
        verify_setup_eks,
        lambda: [item for driver, spec in GENERATED.items() for item in verify_driver(driver, spec)],
        verify_setup_script_contract,
    )
    for check in checks:
        try:
            successes.extend(check())
        except (AssertionError, RuntimeError) as exc:
            failures.append(str(exc))

    if failures:
        print("Storage contract verification failed.", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    for success in successes:
        print(success)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
