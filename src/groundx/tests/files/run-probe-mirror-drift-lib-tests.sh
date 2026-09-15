#!/usr/bin/env bash
set -uo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "FAIL: yq not found on PATH" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/probe-mirror-drift-lib.sh"

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

expect_pass "must-not-block: identical src/mirror renders are not flagged as drift" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/matching-src.yaml" "${fixtures_dir}/matching-mirror.yaml" \
  layout-api ranker-api

expect_fail "must-detect: a diverging mirror render is flagged as drift" \
  probe_mirror_drift_compare \
  "${fixtures_dir}/diverging-src.yaml" "${fixtures_dir}/diverging-mirror.yaml" \
  layout-api ranker-api

echo "probe-mirror-drift-lib tests: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
