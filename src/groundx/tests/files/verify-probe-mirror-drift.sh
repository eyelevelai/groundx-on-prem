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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/probe-mirror-drift-lib.sh"

repo_root="$(cd "${script_dir}/../../../.." && pwd)"
src_chart="${repo_root}/src/groundx"
mirror_chart="${repo_root}/helm"
src_minikube_values="${src_chart}/values/minikube/values.yaml"
mirror_minikube_values="${mirror_chart}/values/minikube/values.yaml"

render_default_src="$(mktemp)"
render_default_mirror="$(mktemp)"
render_ws_src="$(mktemp)"
render_ws_mirror="$(mktemp)"
render_nondefault_override_src="$(mktemp)"
render_nondefault_override_mirror="$(mktemp)"
render_nondefault_override_ws_src="$(mktemp)"
render_nondefault_override_ws_mirror="$(mktemp)"
trap 'rm -f "${render_default_src}" "${render_default_mirror}" "${render_ws_src}" "${render_ws_mirror}" "${render_nondefault_override_src}" "${render_nondefault_override_mirror}" "${render_nondefault_override_ws_src}" "${render_nondefault_override_ws_mirror}"' EXIT

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

nondefault_override_set_args=()
for svc in layout ranker summary extract; do
  nondefault_override_set_args+=(
    "--set" "${svc}.api.probe.liveness.timeoutSeconds=7"
    "--set" "${svc}.api.probe.readiness.timeoutSeconds=9"
    "--set" "${svc}.api.probe.readiness.failureThreshold=5"
  )
done

helm template "${src_chart}" -f "${src_minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  "${nondefault_override_set_args[@]}" \
  > "${render_nondefault_override_src}"
helm template "${mirror_chart}" -f "${mirror_minikube_values}" \
  --set extract.enabled=true --set extract.api.enabled=true \
  "${nondefault_override_set_args[@]}" \
  > "${render_nondefault_override_mirror}"
helm template "${src_chart}" -f "${src_minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  --set workspace.api.probe.liveness.timeoutSeconds=7 \
  --set workspace.api.probe.readiness.timeoutSeconds=9 \
  --set workspace.api.probe.readiness.failureThreshold=5 \
  > "${render_nondefault_override_ws_src}"
helm template "${mirror_chart}" -f "${mirror_minikube_values}" \
  --set workspace.enabled=true --set workspace.token=drift-check-token \
  --set workspace.api.probe.liveness.timeoutSeconds=7 \
  --set workspace.api.probe.readiness.timeoutSeconds=9 \
  --set workspace.api.probe.readiness.failureThreshold=5 \
  > "${render_nondefault_override_ws_mirror}"

fail=0
probe_mirror_drift_compare "${render_default_src}" "${render_default_mirror}" \
  layout-api ranker-api summary-api extract-api || fail=1
probe_mirror_drift_compare "${render_ws_src}" "${render_ws_mirror}" \
  workspace-api || fail=1
probe_mirror_drift_compare "${render_nondefault_override_src}" "${render_nondefault_override_mirror}" \
  layout-api ranker-api summary-api extract-api || fail=1
probe_mirror_drift_compare "${render_nondefault_override_ws_src}" "${render_nondefault_override_ws_mirror}" \
  workspace-api || fail=1

if [ "${fail}" -ne 0 ]; then
  echo "FAIL: helm/ and src/groundx render different probe-timing values for one or more of the five API services" >&2
  exit 1
fi

echo "PASS: src/groundx and helm/ render identical probe-timing values for all five API services, under both chart defaults and an operator override"
