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
  - google OCR credentials render for both chart surfaces
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

# The Google-OCR tests render a credentials file that layout-ocr-credentials.yaml reads
# via .Files.Get. That file must NOT ship in the packaged chart (files/ is packaged), so
# generate a throwaway one for the duration of this gate and remove it on exit. The
# gcv-*.json name is git-ignored, so it can never be committed by accident. We refuse to
# overwrite a pre-existing file at that path and only ever delete files we created here,
# so a developer's own credential file at that path is never clobbered or removed.
OCR_TEST_CREDENTIALS="files/ocr/gcv-test.json"
layout_pvc_values=""
layout_pvc_render=""
ocr_generated_files=()
cleanup() {
  if ((${#ocr_generated_files[@]})); then
    rm -f "${ocr_generated_files[@]}"
  fi
  rmdir src/groundx/files/ocr src/groundx/files helm/files/ocr helm/files 2>/dev/null || true
  rm -f "${layout_pvc_values}" "${layout_pvc_render}"
}
trap cleanup EXIT
for chart in src/groundx helm; do
  ocr_target="${chart}/${OCR_TEST_CREDENTIALS}"
  if [[ -e "${ocr_target}" ]]; then
    echo "Refusing to overwrite existing ${ocr_target}; remove it and re-run the gate." >&2
    exit 1
  fi
  mkdir -p "${chart}/files/ocr"
  cat > "${ocr_target}" <<'JSON'
{
  "type": "service_account",
  "project_id": "groundx-helm-test",
  "private_key_id": "test",
  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",
  "token_uri": "https://oauth2.googleapis.com/token"
}
JSON
  ocr_generated_files+=("${ocr_target}")
done

echo "==> Linting Helm chart surfaces"
helm lint src/groundx
helm lint helm

echo "==> Running Helm unit tests"
helm unittest src/groundx

echo "==> Verifying Google OCR credentials rendering for both chart surfaces"
for chart in src/groundx helm; do
  # Enabled: the credentials ConfigMap resource must actually render. --show-only isolates
  # that one resource, so this cannot be satisfied by the volume's mere reference to the
  # same name (both carry the -ocr-credentials-map token in a full render).
  ocr_configmap="$(helm template ocr-google "${chart}" -f src/groundx/tests/files/values.ocr-google.yaml --show-only templates/resources/layout-ocr-credentials.yaml 2>/dev/null || true)"
  if ! grep -q 'kind: ConfigMap' <<<"${ocr_configmap}" || ! grep -q -- '-ocr-credentials-map' <<<"${ocr_configmap}"; then
    echo "${chart}: google OCR enabled render must create the -ocr-credentials-map ConfigMap resource." >&2
    exit 1
  fi
  # ...and the celery Deployment must mount that ConfigMap and hash it.
  ocr_enabled_render="$(helm template ocr-google "${chart}" -f src/groundx/tests/files/values.ocr-google.yaml)"
  for expected in "ocr-credentials-hash" "credentials-volume"; do
    if ! grep -q -- "${expected}" <<<"${ocr_enabled_render}"; then
      echo "${chart}: google OCR enabled render is missing expected evidence: ${expected}" >&2
      exit 1
    fi
  done
  # Disabled (credentials set, layout.ocr.enabled=false): the ConfigMap resource must NOT
  # render (--show-only fails when the guard drops it to an empty document), and the
  # Deployment must NOT mount a ConfigMap that is never created (the F5 must-not-mount case).
  if helm template ocr-google-disabled "${chart}" -f src/groundx/tests/files/values.ocr-google-disabled.yaml --show-only templates/resources/layout-ocr-credentials.yaml >/dev/null 2>&1; then
    echo "${chart}: google OCR disabled render must not create the -ocr-credentials-map ConfigMap." >&2
    exit 1
  fi
  ocr_disabled_render="$(helm template ocr-google-disabled "${chart}" -f src/groundx/tests/files/values.ocr-google-disabled.yaml)"
  if grep -q -- "credentials-volume" <<<"${ocr_disabled_render}"; then
    echo "${chart}: google OCR disabled render must not mount a ConfigMap that is never created." >&2
    exit 1
  fi
done

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

echo "==> Verifying engine maxImages schema validation"
expect_helm_lint_failure() {
  local chart="$1"
  local expected_description="$2"
  local expected_regex="$3"
  shift 3

  local output
  local status
  set +e
  output="$(helm lint "${chart}" --set engines.default.engineId=test-engine "$@" 2>&1)"
  status=$?
  set -e

  if [[ "${status}" -eq 0 ]]; then
    echo "Expected Helm lint to fail for ${chart}: $*" >&2
    exit 1
  fi
  if [[ "${output}" != *"/engines/default/maxImages"* && "${output}" != *"engines.default.maxImages"* ]]; then
    echo "Helm lint failed for ${chart}, but did not mention engines.default.maxImages." >&2
    echo "${output}" >&2
    exit 1
  fi
  if [[ ! "${output}" =~ ${expected_regex} ]]; then
    echo "Helm lint failed for ${chart}, but did not mention ${expected_description}." >&2
    echo "${output}" >&2
    exit 1
  fi
}

for chart in src/groundx helm; do
  helm lint "${chart}" --set engines.default.engineId=test-engine --set-json engines.default.maxImages=null >/dev/null
  helm lint "${chart}" --set engines.default.engineId=test-engine --set engines.default.maxImages=30 >/dev/null
  expect_helm_lint_failure "${chart}" "a minimum-value failure" "greater than or equal to 1|minimum: got -?[0-9]+, want 1" --set engines.default.maxImages=0
  expect_helm_lint_failure "${chart}" "a minimum-value failure" "greater than or equal to 1|minimum: got -?[0-9]+, want 1" --set engines.default.maxImages=-1
  expect_helm_lint_failure "${chart}" "an invalid-type failure" "Invalid type|Expected:.*integer|got string, want null or integer" --set engines.default.maxImages=many
done

echo "==> Verifying layout inference PVC schema validation"
layout_pvc_values="$(mktemp)"
layout_pvc_render="$(mktemp)"
cat > "${layout_pvc_values}" <<'YAML'
layout:
  inference:
    pvc:
      access: ReadWriteMany
      capacity: 20Gi
      class: eyelevel-efs
      name: layout-model-efs
    replicas:
      desired: 2
YAML

for chart in src/groundx helm; do
  helm lint "${chart}" -f "${layout_pvc_values}" >/dev/null
  helm template layout-pvc "${chart}" -f "${layout_pvc_values}" > "${layout_pvc_render}"
  for expected in \
    "claimName: layout-model-efs" \
    "storageClassName: eyelevel-efs" \
    "storage: 20Gi" \
    "ReadWriteMany"; do
    if ! grep -q "${expected}" "${layout_pvc_render}"; then
      echo "Rendered ${chart} output did not contain expected layout PVC evidence: ${expected}" >&2
      exit 1
    fi
  done
done

echo "==> Verifying deprecated compatibility values contract"
python - <<'PY'
import json
from pathlib import Path

for chart in (Path("src/groundx"), Path("helm")):
    schema = json.loads((chart / "values.schema.json").read_text())
    cluster = schema["properties"]["cluster"]["properties"]
    fields = {
        "cluster.hasMig": cluster["hasMig"],
        "cluster.tls.existingSecret": cluster["tls"]["properties"]["existingSecret"],
    }
    for path, field in fields.items():
        if field.get("deprecated") is not True:
            raise SystemExit(f"{chart}: {path} must be marked deprecated")
        description = field.get("description", "").lower()
        if "accepted for compatibility" not in description or "does not change rendered resources" not in description:
            raise SystemExit(f"{chart}: {path} must describe its inert compatibility behavior")
PY

for chart in src/groundx helm; do
  if ! diff -q \
    <(helm template deprecated-values "${chart}") \
    <(helm template deprecated-values "${chart}" --set cluster.hasMig=true) \
    >/dev/null; then
    echo "${chart}: cluster.hasMig must remain an inert compatibility field in 0.2.7." >&2
    exit 1
  fi
  if ! diff -q \
    <(helm template deprecated-values "${chart}") \
    <(helm template deprecated-values "${chart}" --set cluster.tls.existingSecret=legacy-tls) \
    >/dev/null; then
    echo "${chart}: cluster.tls.existingSecret must remain an inert compatibility field in 0.2.7." >&2
    exit 1
  fi
done

if grep -R -q 'define "groundx\.hasMig"' \
  src/groundx/templates helm/templates; then
  echo "The current chart must not retain an unused groundx.hasMig helper." >&2
  exit 1
fi
if grep -R -q '\.Values\.tls\|cluster\.tls\.existingSecret' \
  src/groundx/templates/NOTES.txt helm/templates/NOTES.txt; then
  echo "Helm notes must not claim unsupported TLS Secret behavior." >&2
  exit 1
fi

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
