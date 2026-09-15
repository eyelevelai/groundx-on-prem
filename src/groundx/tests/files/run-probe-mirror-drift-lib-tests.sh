#!/usr/bin/env bash
set -uo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "FAIL: yq not found on PATH" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/probe-mirror-drift-lib.sh"
set +e

fixtures_dir="${script_dir}/fixtures/probe-mirror-drift"

pass=0
fail=0

expect_pass() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>/dev/null; then
    echo "PASS: ${label}"
    pass=$((pass + 1))
  else
    echo "FAIL: ${label} -- expected the guard to pass (must-not-block case) but it reported drift" >&2
    fail=$((fail + 1))
  fi
}

expect_fail() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>/dev/null; then
    echo "FAIL: ${label} -- expected the guard to detect drift (must-detect case) but it reported clean" >&2
    fail=$((fail + 1))
  else
    echo "PASS: ${label}"
    pass=$((pass + 1))
  fi
}

expect_pass "must-not-block: src/mirror renders that differ only in a non-probe field (image tag) are not flagged as drift" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/matching-src.yaml" "${fixtures_dir}/matching-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a diverging readiness timeoutSeconds is flagged as drift" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/diverging-readiness-timeout-src.yaml" "${fixtures_dir}/diverging-readiness-timeout-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a diverging liveness timeoutSeconds is flagged as drift" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/diverging-liveness-timeout-src.yaml" "${fixtures_dir}/diverging-liveness-timeout-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a diverging readiness failureThreshold is flagged as drift" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/diverging-readiness-threshold-src.yaml" "${fixtures_dir}/diverging-readiness-threshold-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a Deployment absent from the mirror render fails closed rather than comparing empty to empty" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/absent-document-src.yaml" "${fixtures_dir}/absent-document-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a probe field absent from the mirror render fails closed rather than comparing null to null" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/absent-field-src.yaml" "${fixtures_dir}/absent-field-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a Deployment absent from BOTH renders fails closed rather than comparing empty to empty" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/both-absent-document-src.yaml" "${fixtures_dir}/both-absent-document-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a probe field absent from BOTH renders fails closed rather than comparing null to null" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/both-absent-field-src.yaml" "${fixtures_dir}/both-absent-field-mirror.yaml" \
  layout-api ranker-api

echo "probe-mirror-drift-lib tests: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
