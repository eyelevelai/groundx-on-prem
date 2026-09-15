#!/usr/bin/env bash
set -euo pipefail

PROBE_MIRROR_DRIFT_FIELDS=(
  ".spec.template.spec.containers[0].livenessProbe.timeoutSeconds"
  ".spec.template.spec.containers[0].readinessProbe.timeoutSeconds"
  ".spec.template.spec.containers[0].readinessProbe.failureThreshold"
)

probe_mirror_drift_extract() {
  local doc_name="$1"
  local field_path="$2"
  local render_file="$3"
  yq -N "select(.kind == \"Deployment\" and .metadata.name == \"${doc_name}\") | ${field_path}" "${render_file}"
}

probe_mirror_drift_is_unresolved() {
  local value="$1"
  [ -z "${value}" ] || [ "${value}" = "null" ]
}

probe_mirror_drift_compare() {
  local src_render="$1"
  local mirror_render="$2"
  shift 2
  local services=("$@")
  local fail=0
  local svc field src_val mirror_val

  for svc in "${services[@]}"; do
    for field in "${PROBE_MIRROR_DRIFT_FIELDS[@]}"; do
      src_val="$(probe_mirror_drift_extract "${svc}" "${field}" "${src_render}")"
      mirror_val="$(probe_mirror_drift_extract "${svc}" "${field}" "${mirror_render}")"
      if probe_mirror_drift_is_unresolved "${src_val}"; then
        echo "FAIL: ${svc} ${field}: src/groundx render has no Deployment named '${svc}' or is missing this field (got '${src_val}')" >&2
        fail=1
        continue
      fi
      if probe_mirror_drift_is_unresolved "${mirror_val}"; then
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
