#!/usr/bin/env bash
set -euo pipefail

if ! command -v helm >/dev/null 2>&1; then
  echo "FAIL: helm not found on PATH" >&2
  exit 1
fi
if ! command -v yq >/dev/null 2>&1; then
  echo "FAIL: yq not found on PATH" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
src_chart="${repo_root}/src/groundx"
mirror_chart="${repo_root}/helm"
minikube_values="${src_chart}/values/minikube/values.yaml"

fail=0

assert_field() {
  local label="$1"
  local doc_name="$2"
  local field_path="$3"
  local expected="$4"
  local render_file="$5"
  local actual
  actual="$(yq -N "select(.kind == \"Deployment\" and .metadata.name == \"${doc_name}\") | ${field_path}" "${render_file}")"
  if [ "${actual}" != "${expected}" ]; then
    echo "FAIL: ${label} ${doc_name} ${field_path} = '${actual}', expected '${expected}'" >&2
    fail=1
  fi
}

render_default_src="$(mktemp)"
render_default_mirror="$(mktemp)"
render_ws_src="$(mktemp)"
render_ws_mirror="$(mktemp)"
trap 'rm -f "${render_default_src}" "${render_default_mirror}" "${render_ws_src}" "${render_ws_mirror}"' EXIT

helm template "${src_chart}" -f "${minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  > "${render_default_src}"
helm template "${mirror_chart}" -f "${minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  > "${render_default_mirror}"
helm template "${src_chart}" -f "${minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  > "${render_ws_src}"
helm template "${mirror_chart}" -f "${minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  > "${render_ws_mirror}"

for svc in layout-api ranker-api summary-api extract-api; do
  for pair in "src/groundx:${render_default_src}" "helm:${render_default_mirror}"; do
    chart_label="${pair%%:*}"
    render_file="${pair#*:}"
    assert_field "${chart_label}" "${svc}" ".spec.template.spec.containers[0].livenessProbe.timeoutSeconds" "3" "${render_file}"
    assert_field "${chart_label}" "${svc}" ".spec.template.spec.containers[0].readinessProbe.timeoutSeconds" "3" "${render_file}"
    assert_field "${chart_label}" "${svc}" ".spec.template.spec.containers[0].readinessProbe.failureThreshold" "3" "${render_file}"
  done
done

for pair in "src/groundx:${render_ws_src}" "helm:${render_ws_mirror}"; do
  chart_label="${pair%%:*}"
  render_file="${pair#*:}"
  assert_field "${chart_label}" "workspace-api" ".spec.template.spec.containers[0].livenessProbe.timeoutSeconds" "3" "${render_file}"
  assert_field "${chart_label}" "workspace-api" ".spec.template.spec.containers[0].readinessProbe.timeoutSeconds" "3" "${render_file}"
  assert_field "${chart_label}" "workspace-api" ".spec.template.spec.containers[0].readinessProbe.failureThreshold" "3" "${render_file}"
done

if [ "${fail}" -ne 0 ]; then
  echo "FAIL: helm/ and src/groundx disagree on rendered probe-timing values, or a value is missing, for one or more of the five API services" >&2
  exit 1
fi

echo "PASS: src/groundx and helm/ render identical probe-timing values for all five API services"
