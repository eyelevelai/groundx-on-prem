#!/usr/bin/env bash
# GX-17 acceptance: prove every converted credential resource renders `kind: Secret`
# on HEAD and that its rendered payload is byte-identical to the origin/0.2.7 ConfigMap
# payload, for BOTH chart mirrors (src/groundx and helm/). Fails (RED) on the unchanged
# 0.2.7 tree, where these render as ConfigMaps. Requires: pinned helm on PATH, the
# origin/0.2.7 ref present. Read-only except for OCR fixtures it creates under a chart's
# files/ocr; it removes ONLY the exact files (and dirs) it created, never a glob.
set -uo pipefail

base=$(mktemp -d)
CREATED_FILES=()
CREATED_DIRS=()   # child-before-parent order
cleanup() {
  rm -rf "$base"
  local p
  for p in "${CREATED_FILES[@]:-}"; do [ -n "$p" ] && rm -f "$p"; done
  for p in "${CREATED_DIRS[@]:-}"; do [ -n "$p" ] && rmdir "$p" 2>/dev/null; done
  true
}
trap cleanup EXIT
git archive origin/0.2.7 src/groundx helm | tar -x -C "$base"

VD=src/groundx/tests/files
SPECS=(
  "templates/resources/config-yaml.yaml|config.yaml|"
  "templates/resources/ranker-config-py.yaml|config.py|"
  "templates/resources/summary-config-py.yaml|config.py|"
  "templates/resources/layout-config-py.yaml|config.py|"
  "templates/resources/extract-config-py.yaml|config.py|-f $VD/values.extract.ingest.yaml"
  "templates/resources/workspace-config-py.yaml|config.py|-f $VD/values.workspace.yaml"
)

fail=0
payload() { sed -n "/^  $1: |/,/^[^ ]/p"; }

for mirror in src/groundx helm; do
  for spec in "${SPECS[@]}"; do
    IFS='|' read -r file key extra <<<"$spec"
    h=$(helm template gx "$mirror" -n eyelevel $extra --show-only "$file" 2>/dev/null)
    b=$(helm template gx "$base/$mirror" -n eyelevel $extra --show-only "$file" 2>/dev/null)
    if ! grep -q '^kind: Secret' <<<"$h"; then echo "FAIL $mirror/$file: HEAD is not kind: Secret"; fail=1; continue; fi
    ph=$(payload "$key" <<<"$h"); pb=$(payload "$key" <<<"$b")
    if [ -z "$ph" ] || [ "$ph" != "$pb" ]; then echo "FAIL $mirror/$file: $key payload not byte-identical to 0.2.7"; fail=1; fi
  done

  # layout-ocr: inject a unique fixture into the HEAD chart dir (tracked for removal) and
  # into the base copy (under the auto-removed tmp). mktemp X's are end-anchored so the
  # name is actually randomized (a trailing extension would defeat that on BSD mktemp).
  hd="$mirror/files/ocr"
  if [ ! -d "$mirror/files" ]; then mkdir -p "$hd"; CREATED_DIRS=("$hd" "$mirror/files" "${CREATED_DIRS[@]:-}")
  elif [ ! -d "$hd" ]; then mkdir -p "$hd"; CREATED_DIRS=("$hd" "${CREATED_DIRS[@]:-}"); fi
  hf=$(mktemp "$hd/gx17-parity-XXXXXX"); printf '{}' >"$hf"; CREATED_FILES+=("$hf")
  bd="$base/$mirror/files/ocr"; mkdir -p "$bd"; bf=$(mktemp "$bd/gx17-parity-XXXXXX"); printf '{}' >"$bf"
  ha="--set layout.ocr.type=google --set layout.ocr.project=p --set layout.ocr.credentials=files/ocr/$(basename "$hf")"
  ba="--set layout.ocr.type=google --set layout.ocr.project=p --set layout.ocr.credentials=files/ocr/$(basename "$bf")"
  h=$(helm template gx "$mirror" -n eyelevel $ha --show-only templates/resources/layout-ocr-credentials.yaml 2>/dev/null)
  b=$(helm template gx "$base/$mirror" -n eyelevel $ba --show-only templates/resources/layout-ocr-credentials.yaml 2>/dev/null)
  if ! grep -q '^kind: Secret' <<<"$h"; then echo "FAIL $mirror ocr: HEAD is not kind: Secret"; fail=1; fi
  ph=$(payload credentials.json <<<"$h"); pb=$(payload credentials.json <<<"$b")
  if [ -z "$ph" ] || [ "$ph" != "$pb" ]; then echo "FAIL $mirror ocr: credentials.json payload not byte-identical to 0.2.7"; fail=1; fi
done

[ "$fail" = 0 ] && echo "OK: all converted payloads render kind: Secret with 0.2.7-identical content (both mirrors)"
exit $fail
