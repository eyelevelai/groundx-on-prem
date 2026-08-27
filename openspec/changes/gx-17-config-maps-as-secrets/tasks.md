# Tasks — GX-17: Render credential-bearing config maps as Secrets (chart-only)

Each check asserts the target renders as `kind: Secret` (or a pod volume references it via `secretName`). On the unchanged base (`origin/0.2.7`) these render as `ConfigMap`, so every check FAILS (RED); on this branch they render as `Secret`, so every check PASSES (GREEN). `helm` on PATH must be the pinned v3.19.0 (the repo's gate binary).

## 1. Convert `config-yaml-map` to a Secret (both mirrors)

- [x] 1.1 `src/groundx/templates/resources/config-yaml.yaml` renders `config-yaml-map` as `kind: Secret` (`stringData`), same name and `config.yaml` content.
  check: helm template gx src/groundx -n eyelevel --show-only templates/resources/config-yaml.yaml | grep -q '^kind: Secret'
- [x] 1.2 The `helm/` manual mirror renders `config-yaml-map` as a Secret identically.
  check: helm template gx helm -n eyelevel --show-only templates/resources/config-yaml.yaml | grep -q '^kind: Secret'

## 2. Convert the per-service `*-config-py-map` to Secrets

- [x] 2.1 The default-rendered config-py maps (`ranker`, `summary`, `layout`) render as Secrets, none as ConfigMap.
  check: bash -c 'out=$(helm template gx src/groundx -n eyelevel); ! grep -B3 -E "name: (ranker|summary|layout)-config-py-map" <<<"$out" | grep -q "kind: ConfigMap"'
- [x] 2.2 `extract-config-py-map` renders as a Secret when extract is enabled.
  check: helm template gx src/groundx -n eyelevel -f src/groundx/tests/files/values.extract.ingest.yaml --show-only templates/resources/extract-config-py.yaml | grep -q '^kind: Secret'
- [x] 2.3 `workspace-config-py-map` renders as a Secret when workspace is enabled.
  check: helm template gx src/groundx -n eyelevel -f src/groundx/tests/files/values.workspace.yaml --show-only templates/resources/workspace-config-py.yaml | grep -q '^kind: Secret'

## 3. Convert `layout-ocr-credentials-map` to a Secret

- [x] 3.1 With Google OCR enabled, `layout-ocr-credentials.yaml` renders `layout-ocr-credentials-map` as a Secret carrying `credentials.json`.
  check: bash -c 'trap "rm -f src/groundx/files/ocr/credentials.json; rmdir src/groundx/files/ocr src/groundx/files 2>/dev/null" EXIT; mkdir -p src/groundx/files/ocr && printf "{}" > src/groundx/files/ocr/credentials.json && helm template gx src/groundx -n eyelevel --set layout.ocr.type=google --set layout.ocr.project=p --set layout.ocr.credentials=files/ocr/credentials.json --show-only templates/resources/layout-ocr-credentials.yaml | grep -q "^kind: Secret"'

## 4. Switch the credential-map pod volumes to a Secret source

- [x] 4.1 The golang deployment mounts `config-volume` from the `config-yaml-map` Secret (not a ConfigMap).
  check: bash -c "helm template gx src/groundx -n eyelevel --show-only templates/app/golang.yaml | grep -A2 'name: config-volume' | grep -q 'secretName: config-yaml-map'"

## 5. Keep non-credential maps as ConfigMaps + docs

- [x] 5.1 `config-models-map` (a non-credential map) still renders as a ConfigMap — the conversion is scoped to credential maps only.
  check: helm template gx src/groundx -n eyelevel --show-only templates/resources/config-models.yaml | grep -q '^kind: ConfigMap'
- [x] 5.2 Update `AGENTS.md` / `README.md` to describe the credential maps as Secrets.
  check: n/a — documentation change, no behavior.

## Hand-off

- [x] Push the branch (`gx-17-config-maps-as-secrets`, base `origin/0.2.7`) and open PR #78.
  check: n/a — hand-off action; verified by the pre-push gate green on push.

## Deferred follow-ups

- [ ] AGE-296 — flip the on-prem harness (docs + `scan-on-prem.mjs` pin + the `kubectl get configmap config-yaml-map` diagnostic) from ConfigMap to Secret in the same 0.2.7 doc pass; regenerate the DERIVED harness.
  check: n/a — separate ticket (AGE-296).
- [ ] GX-18 — rotate the exposed credentials after the Secret paths ship.
  check: n/a — post-ship operational step, not chart code.
