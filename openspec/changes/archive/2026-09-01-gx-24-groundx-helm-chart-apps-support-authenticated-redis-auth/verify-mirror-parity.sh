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

check_identical "main cache credentialed config-yaml session blocks" \
  templates/resources/config-yaml.yaml \
  --set cache.existing.addr=mirror.example.com --set cache.password=mirrorpass --set cache.username=mirroruser

check_identical "layout broker/result/metrics URLs, main+metrics identities credentialed" \
  templates/resources/layout-config-py.yaml \
  --set cache.existing.addr=mirror.example.com --set cache.password=mirrorpass --set cache.username=mirroruser

check_identical "ranker searchBroker/searchResultBroker, ranker identity credentialed" \
  templates/resources/ranker-config-py.yaml \
  --set ranker.cache.addr=mirror-ranker.example.com --set ranker.cache.password=rankermirror

check_identical "summary broker/result URLs, main identity credentialed" \
  templates/resources/summary-config-py.yaml \
  --set cache.existing.addr=mirror.example.com --set cache.password=mirrorpass

exit "$fail"
