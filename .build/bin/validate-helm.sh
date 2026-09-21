#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

# Resolve a Python interpreter (the verifier scripts are python3; prefer it, fall back to python).
# Works whether the host exposes it as python3 or python; fails fast if neither is present.
PY="$(command -v python3 || command -v python)" || { echo "no python interpreter on PATH (need python3 or python)" >&2; exit 1; }

RUN_JUNIT=0

usage() {
  cat <<'USAGE'
Usage: .build/bin/validate-helm.sh [--junit]

Runs the GroundX Helm production chart gate from one stable entrypoint:
  - helm lint for both chart surfaces
  - pinned helm-unittest plugin version guard
  - guard-script unit tests (stdlib scripts under .build/tests)
  - helm unittest for src/groundx
  - snapshot-rewrite-on-run guard (see GX-22)
  - snapshot label guard unit tests
  - snapshot label guard
  - workspace chart contract verifier
  - storage chart, generated AWS values, and template-mirror contract verifier
  - targeted render checks for both chart surfaces
  - git whitespace check

Options:
  --junit  Also write reports/helm-unittest.xml.
USAGE
}

for arg in "$@"; do
  case "${arg}" in
    --junit)
      RUN_JUNIT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SNAPSHOT_STABILITY_HASHFILE="$(mktemp)"
trap 'rm -f "${SNAPSHOT_STABILITY_HASHFILE}"' EXIT

run_helm_unittest_and_verify_stability() {
  local marker_suffix="$1"; shift
  helm unittest "$@" src/groundx
  echo "==> Verifying helm unittest ${marker_suffix}did not rewrite committed snapshots as a side effect (see GX-22)"
  "${PY}" .build/bin/verify-helm-snapshot-stability.py verify "${SNAPSHOT_STABILITY_HASHFILE}"
}

echo "==> Capturing snapshot state before running any Helm tooling (see GX-22)"
"${PY}" .build/bin/verify-helm-snapshot-stability.py capture "${SNAPSHOT_STABILITY_HASHFILE}"

echo "==> Linting Helm chart surfaces"
helm lint src/groundx
helm lint helm

echo "==> Verifying pinned helm-unittest plugin version"
"${PY}" .build/bin/verify-helm-unittest-plugin-version.py

echo "==> Verifying every guard-script test file is referenced in validate-helm.sh"
SELF_PATH="${ROOT_DIR}/.build/bin/validate-helm.sh"
for test_file in .build/tests/test_*.py; do
  base="$(basename "${test_file}")"
  grep -qF "${base}" "${SELF_PATH}" || { echo "orphaned guard-script test file not referenced in validate-helm.sh: ${base}" >&2; exit 1; }
done

echo "==> Running guard-script unit tests"
"${PY}" .build/tests/test_verify_helm_unittest_plugin_version.py
"${PY}" .build/tests/test_verify_helm_snapshot_stability.py

echo "==> Running Helm unit tests"
run_helm_unittest_and_verify_stability ""

echo "==> Verifying extract-agent image settings validation"
expect_helm_template_failure() {
  local chart="$1"
  local expected="$2"
  shift 2

  local output
  local status
  set +e
  output="$(helm template invalid-image-settings "${chart}" -f src/groundx/values/extract/values.yaml "$@" 2>&1 >/dev/null)"
  status=$?
  set -e

  if [[ "${status}" -eq 0 ]]; then
    echo "Expected Helm render to fail for ${chart}: $*" >&2
    exit 1
  fi
  if [[ "${output}" != *"${expected}"* ]]; then
    echo "Helm render failed for ${chart}, but did not mention '${expected}'." >&2
    echo "${output}" >&2
    exit 1
  fi
}

for chart in src/groundx helm; do
  expect_helm_template_failure "${chart}" "imageTransport" --set extract.agent.imageTransport=auto
  expect_helm_template_failure "${chart}" "minLongEdgePx" --set extract.agent.targetLongEdgePx=899 --set extract.agent.minLongEdgePx=900
  expect_helm_template_failure "${chart}" "jpegQualities" --set-json extract.agent.jpegQualities='[96]'
  expect_helm_template_failure "${chart}" "maxImagePayloadBytes" --set extract.agent.maxImagePayloadBytes=0
done

echo "==> Verifying Helm snapshots did not silently drop empty renders"
"${PY}" .build/tests/test_verify_helm_snapshots.py
"${PY}" .build/bin/verify-helm-snapshots.py

echo "==> Verifying workspace chart contract"
"${PY}" .build/bin/verify-workspace-chart.py

echo "==> Verifying storage contract"
"${PY}" .build/bin/verify-storage-contract.py

echo "==> Rendering workspace chart fixtures"
helm template workspace-contract src/groundx \
  -f src/groundx/tests/files/values.workspace.yaml \
  -f src/groundx/tests/files/values.workspace-metrics.yaml \
  >/dev/null
helm template workspace-contract helm \
  -f src/groundx/tests/files/values.workspace.yaml \
  -f src/groundx/tests/files/values.workspace-metrics.yaml \
  >/dev/null

echo "==> Validating workspace smoke/E2E script syntax and wording"
bash -n .build/bin/smoke-workspace-runner.sh
bash -n .build/bin/workspace-runner-git-e2e.sh
bash -n .build/bin/workspace-runner-file-api-e2e.sh
if grep -R --exclude='validate-helm.sh' "workspace-runner-e2e\\.sh" README.md .build/bin src helm >/dev/null 2>&1; then
  echo "Workspace docs/scripts must use the split git/file-api E2E entrypoints, not workspace-runner-e2e.sh." >&2
  exit 1
fi
if grep -R "pull request creatio[n]\\|merge the managed P[R]" README.md .build/bin >/dev/null 2>&1; then
  echo "Workspace docs/scripts must describe publish as CI/CD, not PR/MR creation." >&2
  exit 1
fi

if [[ "${RUN_JUNIT}" == "1" ]]; then
  echo "==> Writing Helm unittest JUnit report"
  mkdir -p reports
  run_helm_unittest_and_verify_stability "(--junit) " -o junit --output-file reports/helm-unittest.xml
fi

echo "==> Checking diff whitespace"
git diff --check

echo "==> Helm chart checks passed"
