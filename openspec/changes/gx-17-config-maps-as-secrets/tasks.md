# Tasks — GX-17: Render credential-bearing config maps as Secrets (chart-only)

Each runnable check is a **positive** assertion that the target renders `kind: Secret` **and** still carries its payload key (so a resource that silently stopped rendering fails the check, it cannot pass by disappearing). On the unchanged base (`origin/0.2.7`) these resources render `kind: ConfigMap`, so **every runnable check below FAILS (RED)**; on this branch they render `kind: Secret`, so every one PASSES (GREEN). `helm` on PATH must be the pinned v3.19.0 (the repo's gate binary).

Scope of what these checks prove: the resource-kind flip, that the payload key is still present, and that the pod volume reads from the Secret. **Byte-identical payload parity** with 0.2.7 is not re-proven per check (a self-contained check has no base to diff against); it was established at review by diffing every changed `helm unittest` snapshot line, where the only changes were `kind`, the `data:`/`stringData:` wrapper, the `config-hash`, and the volume source, with no change inside any `config.yaml` / `config.py` / `credentials.json` payload.

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

## 4. Switch the credential-map pod volumes to a Secret source

- [x] 4.1 The golang deployment mounts `config-volume` from the `config-yaml-map` Secret (not a ConfigMap).
  check: bash -c "helm template gx src/groundx -n eyelevel --show-only templates/app/golang.yaml | grep -A2 'name: config-volume' | grep -q 'secretName: config-yaml-map'"

## 5. Scope guard + docs (not RED/GREEN behavioral checks)

- [x] 5.1 Non-credential maps stay ConfigMaps — the conversion does not widen beyond credential-bearing resources.
  check: n/a — a must-not-change invariant, not new behavior: `config-models-map`/`*-supervisord-conf`/`*-gunicorn-conf-py`/`ldconfig-symlink` render as `ConfigMap` on both base and branch, so a runnable check here passes on the unchanged base (it is not a valid RED check). Covered by the `helm unittest` golden-snapshot suite, which pins these unchanged.
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
