# Tasks — GX-17: Render credential-bearing config maps as Secrets (chart-only)

Every check is runnable. Each is a **positive** assertion: the target renders `kind: Secret` (and carries its payload key, or a pod volume reads it via `secretName`, or its payload is byte-identical to 0.2.7). On the unchanged base (`origin/0.2.7`) the credential resources render `kind: ConfigMap`, so **every check FAILS (RED)**; on this branch they render `kind: Secret`, so every check PASSES (GREEN). `helm` on PATH must be the pinned v3.19.0. The byte-identity checks (§6) read the base render via `git archive origin/0.2.7`, so the `origin/0.2.7` ref must be present (the pipeline fetches it).

## 1. Convert `config-yaml-map` to a Secret (both mirrors)

- [x] 1.1 `src/groundx/templates/resources/config-yaml.yaml` renders `config-yaml-map` as `kind: Secret` with `stringData` still carrying `config.yaml`.
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --show-only templates/resources/config-yaml.yaml); grep -q "^kind: Secret" <<<"$o" && grep -q "^stringData:" <<<"$o" && grep -q "config.yaml:" <<<"$o"'
- [x] 1.2 The `helm/` manual mirror renders `config-yaml-map` as a Secret carrying `config.yaml` identically.
  check: bash -c 'o=$(helm template gx helm -n eyelevel --show-only templates/resources/config-yaml.yaml); grep -q "^kind: Secret" <<<"$o" && grep -q "^stringData:" <<<"$o" && grep -q "config.yaml:" <<<"$o"'

## 2. Convert the per-service `*-config-py-map` to Secrets

- [x] 2.1 The default-rendered config-py maps (`ranker`, `summary`, `layout`) each render as a Secret still carrying `config.py`.
  check: bash -c 'for r in ranker summary layout; do o=$(helm template gx src/groundx -n eyelevel --show-only templates/resources/$r-config-py.yaml) || exit 1; grep -q "^kind: Secret" <<<"$o" || exit 1; grep -q "config.py:" <<<"$o" || exit 1; done'
- [x] 2.2 `extract-config-py-map` renders as a Secret carrying `config.py` when extract is enabled.
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel -f src/groundx/tests/files/values.extract.ingest.yaml --show-only templates/resources/extract-config-py.yaml); grep -q "^kind: Secret" <<<"$o" && grep -q "config.py:" <<<"$o"'
- [x] 2.3 `workspace-config-py-map` renders as a Secret carrying `config.py` when workspace is enabled.
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel -f src/groundx/tests/files/values.workspace.yaml --show-only templates/resources/workspace-config-py.yaml); grep -q "^kind: Secret" <<<"$o" && grep -q "config.py:" <<<"$o"'

## 3. Convert `layout-ocr-credentials-map` to a Secret

- [x] 3.1 With Google OCR enabled, `layout-ocr-credentials.yaml` renders `layout-ocr-credentials-map` as a Secret carrying `credentials.json`. Uses a unique `mktemp` fixture under `files/ocr/` (never the fixed `credentials.json`, so it cannot clobber a real untracked credential) and removes only what it created.
  check: bash -c 'd=src/groundx/files/ocr; created=0; [ -d "$d" ] || { mkdir -p "$d"; created=1; }; f=$(mktemp "$d/gx17-acc-XXXXXX.json"); trap "rm -f \"$f\"; [ \"$created\" = 1 ] && rmdir \"$d\" src/groundx/files 2>/dev/null; true" EXIT; printf "{}" > "$f"; rel=${f#src/groundx/}; o=$(helm template gx src/groundx -n eyelevel --set layout.ocr.type=google --set layout.ocr.project=p --set layout.ocr.credentials="$rel" --show-only templates/resources/layout-ocr-credentials.yaml); grep -q "^kind: Secret" <<<"$o" && grep -q "credentials.json:" <<<"$o"'

## 4. Switch every credential-map pod volume to a Secret source

- [x] 4.1 golang deployment mounts `config-volume` from the `config-yaml-map` Secret.
  check: bash -c "helm template gx src/groundx -n eyelevel --show-only templates/app/golang.yaml | grep -A2 'name: config-volume' | grep -q 'secretName: config-yaml-map'"
- [x] 4.2 metrics deployment mounts `config-volume` from the `config-yaml-map` Secret.
  check: bash -c "helm template gx src/groundx -n eyelevel -f src/groundx/tests/files/values.workspace-metrics.yaml --show-only templates/app/metrics.yaml | grep -A2 'name: config-volume' | grep -q 'secretName: config-yaml-map'"
- [x] 4.3 api deployments mount `config-volume` from a `*-config-py-map` Secret.
  check: bash -c "helm template gx src/groundx -n eyelevel --show-only templates/app/api.yaml | grep -A2 'name: config-volume' | grep -q 'secretName: ranker-config-py-map'"
- [x] 4.4 inference deployments mount `config-volume` from a `*-config-py-map` Secret.
  check: bash -c "helm template gx src/groundx -n eyelevel --show-only templates/app/inference.yaml | grep -A2 'name: config-volume' | grep -q 'secretName: ranker-config-py-map'"
- [x] 4.5 celery deployments mount `config-volume` from a `*-config-py-map` Secret.
  check: bash -c "helm template gx src/groundx -n eyelevel -f src/groundx/tests/files/values.extract.ingest.yaml --show-only templates/app/celery.yaml | grep -A2 'name: config-volume' | grep -q 'secretName: extract-config-py-map'"

## 5. Scope guard (a non-credential map stays a ConfigMap)

- [x] 5.1 The conversion does not widen beyond credential-bearing resources: `config-models-map` stays a `ConfigMap` while a credential map (`config-yaml-map`) became a `Secret`. Folded into one check so it fails RED (the Secret half) and proves the scope boundary (the ConfigMap half) at once.
  check: bash -c 'cm=$(helm template gx src/groundx -n eyelevel --show-only templates/resources/config-models.yaml); sec=$(helm template gx src/groundx -n eyelevel --show-only templates/resources/config-yaml.yaml); grep -q "^kind: ConfigMap" <<<"$cm" && grep -q "^kind: Secret" <<<"$sec"'

## 6. Byte-identical payload parity vs 0.2.7 (runnable)

- [x] 6.1 The `config.yaml` payload the Secret carries is byte-identical to the 0.2.7 ConfigMap payload (only the kind and the `data:`/`stringData:` wrapper changed). Renders the base via `git archive origin/0.2.7`, asserts the branch renders a Secret, and diffs the payload block.
  check: bash -c 'set -e; tmp=$(mktemp -d); trap "rm -rf \"$tmp\"" EXIT; git archive origin/0.2.7 src/groundx | tar -x -C "$tmp"; h=$(helm template gx src/groundx -n eyelevel --show-only templates/resources/config-yaml.yaml); grep -q "^kind: Secret" <<<"$h"; b=$(helm template gx "$tmp/src/groundx" -n eyelevel --show-only templates/resources/config-yaml.yaml); pb=$(sed -n "/^  config\.yaml: |/,/^[^ ]/p" <<<"$b"); ph=$(sed -n "/^  config\.yaml: |/,/^[^ ]/p" <<<"$h"); [ -n "$pb" ] && [ "$pb" = "$ph" ]'
- [x] 6.2 The `config.py` payload (ranker) the Secret carries is byte-identical to the 0.2.7 ConfigMap payload.
  check: bash -c 'set -e; tmp=$(mktemp -d); trap "rm -rf \"$tmp\"" EXIT; git archive origin/0.2.7 src/groundx | tar -x -C "$tmp"; h=$(helm template gx src/groundx -n eyelevel --show-only templates/resources/ranker-config-py.yaml); grep -q "^kind: Secret" <<<"$h"; b=$(helm template gx "$tmp/src/groundx" -n eyelevel --show-only templates/resources/ranker-config-py.yaml); pb=$(sed -n "/^  config\.py: |/,/^[^ ]/p" <<<"$b"); ph=$(sed -n "/^  config\.py: |/,/^[^ ]/p" <<<"$h"); [ -n "$pb" ] && [ "$pb" = "$ph" ]'

## 7. Docs

- [x] 7.1 Update `AGENTS.md` / `README.md` to describe the credential maps as Secrets.
  check: n/a — documentation change, no behavior.

## Hand-off

- [x] Push the branch (`gx-17-config-maps-as-secrets`, base `origin/0.2.7`) and open PR #78.
  check: n/a — hand-off action; verified by the pre-push gate green on push.

## Deferred follow-ups

- [ ] AGE-296 — flip the on-prem harness (docs + `scan-on-prem.mjs` pin + the `kubectl get configmap config-yaml-map` diagnostic) from ConfigMap to Secret in the same 0.2.7 doc pass; regenerate the DERIVED harness.
  check: n/a — separate ticket (AGE-296).
- [ ] GX-18 — rotate the exposed credentials after the Secret paths ship.
  check: n/a — post-ship operational step, not chart code.
