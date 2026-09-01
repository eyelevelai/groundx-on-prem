#!/usr/bin/env bash
# GX-24: verify src/groundx and the helm/ manual mirror render the new
# Redis-credential behavior identically (schema, raw session-block credential,
# and percent-encoded broker-URL credential) for the three touched identities.
#
# Fails closed: any render error (e.g. the schema not yet declaring the new
# keys) or any content mismatch between the two chart surfaces is a failure.
#
# Known, out-of-scope exception (see proposal.md / design.md D-Risks): helm/'s
# Chart.yaml carries a pre-existing, unrelated version drift (0.2.6 vs
# src/groundx's 0.2.7) that this change does not touch. That drift surfaces in
# every rendered manifest's default labels (appVersion/chart/version), so it
# is stripped before comparing — this script's job is credential-render
# parity, not chart-version parity.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

fail=0

render() {
  local chart="$1"
  shift
  helm template gx "$chart" -n eyelevel "$@"
}

strip_known_version_drift() {
  # Drop the three default-label lines derived from Chart.yaml's version
  # fields (appVersion/chart/version) — the only known, out-of-scope
  # difference between the two chart surfaces.
  grep -Ev '^ *(appVersion|chart|version): ' <<<"$1"
}

check_identical() {
  local desc="$1" tmpl="$2"
  shift 2
  local a b
  a="$(render src/groundx --show-only "$tmpl" "$@" 2>&1)"
  if [[ $? -ne 0 ]]; then
    echo "FAIL ($desc): src/groundx render errored:" >&2
    echo "$a" >&2
    fail=1
    return
  fi
  b="$(render helm --show-only "$tmpl" "$@" 2>&1)"
  if [[ $? -ne 0 ]]; then
    echo "FAIL ($desc): helm/ render errored:" >&2
    echo "$b" >&2
    fail=1
    return
  fi
  a="$(strip_known_version_drift "$a")"
  b="$(strip_known_version_drift "$b")"
  if [[ "$a" != "$b" ]]; then
    echo "FAIL ($desc): src/groundx and helm/ renders differ:" >&2
    diff <(echo "$a") <(echo "$b") >&2 || true
    fail=1
  fi
}

# Both surfaces must FAIL identically on the bundled-credential render (F10 / spec.md's
# "both mirrors fail identically on the bundled-cache case" scenario) - a chart-surface
# render divergence on the failure path is just as much a parity break as one on a
# successful render.
check_both_fail_identically() {
  local desc="$1" tmpl="$2"
  shift 2
  local a b rc_a rc_b
  a="$(render src/groundx --show-only "$tmpl" "$@" 2>&1)"
  rc_a=$?
  b="$(render helm --show-only "$tmpl" "$@" 2>&1)"
  rc_b=$?
  if [[ $rc_a -eq 0 || $rc_b -eq 0 ]]; then
    echo "FAIL ($desc): expected both renders to fail, got exit $rc_a (src/groundx) / $rc_b (helm/)" >&2
    fail=1
    return
  fi
  if [[ "$a" != "$b" ]]; then
    echo "FAIL ($desc): src/groundx and helm/ failure output differs:" >&2
    diff <(echo "$a") <(echo "$b") >&2 || true
    fail=1
  fi
}

# cache.metrics.enabled=false isolates main-cache-credential parity from the metrics
# identity's own bundled-vs-external guard (F4/F1) - these three checks are about the
# main identity only.
check_identical "main cache credentialed config-yaml session blocks" \
  templates/resources/config-yaml.yaml \
  --set cache.metrics.enabled=false \
  --set cache.existing.addr=mirror.example.com --set cache.password=mirrorpass --set cache.username=mirroruser

check_identical "layout broker/result/metrics URLs, main+metrics identities credentialed" \
  templates/resources/layout-config-py.yaml \
  --set cache.metrics.enabled=false \
  --set cache.existing.addr=mirror.example.com --set cache.password=mirrorpass --set cache.username=mirroruser

check_identical "ranker searchBroker/searchResultBroker, ranker identity credentialed" \
  templates/resources/ranker-config-py.yaml \
  --set ranker.cache.addr=mirror-ranker.example.com --set ranker.cache.password=rankermirror

check_identical "summary broker/result URLs, main identity credentialed" \
  templates/resources/summary-config-py.yaml \
  --set cache.metrics.enabled=false \
  --set cache.existing.addr=mirror.example.com --set cache.password=mirrorpass

check_both_fail_identically "bundled-cache credential render fails identically on both surfaces" \
  templates/resources/config-yaml.yaml \
  --set cache.password=mirrorpass

exit "$fail"
