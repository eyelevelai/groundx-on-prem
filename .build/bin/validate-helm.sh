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
  - snapshot label guard
  - workspace chart contract verifier
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

echo "==> Verifying Helm snapshots did not silently drop empty renders"
python .build/bin/verify-helm-snapshots.py

echo "==> Verifying workspace chart contract"
python .build/bin/verify-workspace-chart.py

echo "==> Rendering workspace chart fixtures"
helm template workspace-contract src/groundx \
  -f src/groundx/tests/files/values.workspace.yaml \
  -f src/groundx/tests/files/values.workspace-metrics.yaml \
  >/dev/null
helm template workspace-contract helm \
  -f src/groundx/tests/files/values.workspace.yaml \
  -f src/groundx/tests/files/values.workspace-metrics.yaml \
  >/dev/null

if [[ "${RUN_JUNIT}" == "1" ]]; then
  echo "==> Writing Helm unittest JUnit report"
  mkdir -p reports
  helm unittest -o junit --output-file reports/helm-unittest.xml src/groundx
fi

echo "==> Checking diff whitespace"
git diff --check

echo "==> Helm chart checks passed"
