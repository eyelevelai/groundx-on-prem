#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

RUN_JUNIT=0

usage() {
  cat <<'USAGE'
Usage: .build/bin/validate-helm.sh [--junit]

Runs the GroundX Helm production chart gate from one stable entrypoint:
  - helm lint for both chart surfaces
  - helm unittest for src/groundx
  - snapshot label guard unit tests
  - snapshot label guard
  - workspace chart contract verifier
  - storage chart and generated AWS values contract verifier
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

echo "==> Linting Helm chart surfaces"
helm lint src/groundx
helm lint helm

echo "==> Running Helm unit tests"
helm unittest src/groundx

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
  expect_helm_template_failure "${chart}" "minDpi" --set extract.agent.targetDpi=99 --set extract.agent.minDpi=100
  expect_helm_template_failure "${chart}" "maxImagePayloadBytes" --set extract.agent.maxImagePayloadBytes=0
done

echo "==> Verifying Helm snapshots did not silently drop empty renders"
python .build/tests/test_verify_helm_snapshots.py
python .build/bin/verify-helm-snapshots.py

echo "==> Verifying workspace chart contract"
python .build/bin/verify-workspace-chart.py

echo "==> Verifying storage contract"
python .build/bin/verify-storage-contract.py

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
  helm unittest -o junit --output-file reports/helm-unittest.xml src/groundx
fi

echo "==> Checking diff whitespace"
git diff --check

echo "==> Helm chart checks passed"
