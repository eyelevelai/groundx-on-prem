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

PROBE_FIELDS=(
  ".spec.template.spec.containers[0].livenessProbe.timeoutSeconds"
  ".spec.template.spec.containers[0].readinessProbe.timeoutSeconds"
  ".spec.template.spec.containers[0].readinessProbe.failureThreshold"
)

extract_field() {
  local doc_name="$1"
  local field_path="$2"
  local render_file="$3"
  yq -N "select(.kind == \"Deployment\" and .metadata.name == \"${doc_name}\") | ${field_path}" "${render_file}"
}

compare_renders() {
  local src_render="$1"
  local mirror_render="$2"
  shift 2
  local fail=0 svc field src_val mirror_val

  for svc in "$@"; do
    for field in "${PROBE_FIELDS[@]}"; do
      src_val="$(extract_field "${svc}" "${field}" "${src_render}")"
      mirror_val="$(extract_field "${svc}" "${field}" "${mirror_render}")"
      if [ -z "${src_val}" ] || [ "${src_val}" = "null" ]; then
        echo "FAIL: ${svc} ${field}: src/groundx render has no Deployment named '${svc}' or is missing this field (got '${src_val}')" >&2
        fail=1
        continue
      fi
      if [ -z "${mirror_val}" ] || [ "${mirror_val}" = "null" ]; then
        echo "FAIL: ${svc} ${field}: helm render has no Deployment named '${svc}' or is missing this field (got '${mirror_val}')" >&2
        fail=1
        continue
      fi
      if [ "${src_val}" != "${mirror_val}" ]; then
        echo "FAIL: ${svc} ${field}: src/groundx='${src_val}' helm='${mirror_val}'" >&2
        fail=1
      fi
    done
  done

  return "${fail}"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../../.." && pwd)"
src_chart="${repo_root}/src/groundx"
mirror_chart="${repo_root}/helm"
src_minikube_values="${src_chart}/values/minikube/values.yaml"
mirror_minikube_values="${mirror_chart}/values/minikube/values.yaml"

render_default_src="$(mktemp)"
render_default_mirror="$(mktemp)"
render_ws_src="$(mktemp)"
render_ws_mirror="$(mktemp)"
render_override_src="$(mktemp)"
render_override_mirror="$(mktemp)"
render_override_ws_src="$(mktemp)"
render_override_ws_mirror="$(mktemp)"
trap 'rm -f "${render_default_src}" "${render_default_mirror}" "${render_ws_src}" "${render_ws_mirror}" "${render_override_src}" "${render_override_mirror}" "${render_override_ws_src}" "${render_override_ws_mirror}"' EXIT

helm template "${src_chart}" -f "${src_minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  > "${render_default_src}"
helm template "${mirror_chart}" -f "${mirror_minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  > "${render_default_mirror}"
helm template "${src_chart}" -f "${src_minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  > "${render_ws_src}"
helm template "${mirror_chart}" -f "${mirror_minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  > "${render_ws_mirror}"

override_set_args=()
for svc_spec in "layout:7:9:5" "ranker:11:13:6" "summary:15:17:8" "extract:19:21:10"; do
  IFS=':' read -r svc lv rt rf <<< "${svc_spec}"
  override_set_args+=(
    "--set" "${svc}.api.probe.liveness.timeoutSeconds=${lv}"
    "--set" "${svc}.api.probe.readiness.timeoutSeconds=${rt}"
    "--set" "${svc}.api.probe.readiness.failureThreshold=${rf}"
  )
done

helm template "${src_chart}" -f "${src_minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  "${override_set_args[@]}" \
  > "${render_override_src}"
helm template "${mirror_chart}" -f "${mirror_minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  "${override_set_args[@]}" \
  > "${render_override_mirror}"
helm template "${src_chart}" -f "${src_minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  --set workspace.api.probe.liveness.timeoutSeconds=23 \
  --set workspace.api.probe.readiness.timeoutSeconds=25 \
  --set workspace.api.probe.readiness.failureThreshold=12 \
  > "${render_override_ws_src}"
helm template "${mirror_chart}" -f "${mirror_minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  --set workspace.api.probe.liveness.timeoutSeconds=23 \
  --set workspace.api.probe.readiness.timeoutSeconds=25 \
  --set workspace.api.probe.readiness.failureThreshold=12 \
  > "${render_override_ws_mirror}"

fail=0
compare_renders "${render_default_src}" "${render_default_mirror}" \
  layout-api ranker-api summary-api extract-api || fail=1
compare_renders "${render_ws_src}" "${render_ws_mirror}" \
  workspace-api || fail=1
compare_renders "${render_override_src}" "${render_override_mirror}" \
  layout-api ranker-api summary-api extract-api || fail=1
compare_renders "${render_override_ws_src}" "${render_override_ws_mirror}" \
  workspace-api || fail=1

if [ "${fail}" -ne 0 ]; then
  echo "FAIL: helm/ and src/groundx render different probe-timing values for one or more of the five API services" >&2
  exit 1
fi

echo "PASS: src/groundx and helm/ render identical probe-timing values for all five API services, under both chart defaults and an operator override"
