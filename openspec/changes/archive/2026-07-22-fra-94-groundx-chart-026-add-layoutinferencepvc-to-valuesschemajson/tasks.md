## 1. RED — prove the current schema rejects `layout.inference.pvc`

- [x] 1.1 Create a scratch values file (e.g. `/tmp/fra-94-layout-pvc-test-values.yaml`, not
      committed) that sets `layout.inference.pvc.access`, `.capacity`, `.class`, `.name` (any
      valid strings) alongside the chart's minimal required values (mirror
      `src/groundx/values/minikube/values.yaml` as the base).
- [x] 1.2 Run `helm lint src/groundx -f <scratch-values>` and `helm template src/groundx -f
      <scratch-values>` against the **current, unmodified** `src/groundx/values.schema.json`.
      Confirm both **fail** with a schema validation error naming `layout.inference` /
      `additionalProperties` / `pvc` (the correct-polarity RED — it must fail because `pvc` is an
      unrecognized property under `layout.inference`, not for an unrelated reason such as a
      missing required value).

## 2. GREEN — add the `pvc` property to both schema files

- [x] 2.1 In `src/groundx/values.schema.json`, insert the `pvc` property block into
      `layout.inference.properties`, alphabetically between `nodeSelector` and `queue`, verbatim
      identical to `ranker.inference.properties.pvc` (object with `access`, `capacity`, `class`,
      `name`, each `type: string`, `additionalProperties: false`). Do not change
      `layout.inference.required` (stays `["enabled"]`) or any other key in the block.
- [x] 2.2 Hand-mirror the identical `pvc` block into `helm/values.schema.json` at the structurally
      identical location (`layout.inference.properties`, between `nodeSelector` and `queue`).
- [x] 2.3 Re-run the same `helm lint` / `helm template` commands from 1.2 with the same scratch
      values file against the now-modified `src/groundx/values.schema.json`. Confirm both
      **succeed** (no schema validation error) and that the rendered `layout-inference`
      Deployment/PVC manifest includes the configured PVC volume/mount.

## 3. Verify — regression + byte-identity + repo quality gates

- [x] 3.1 Run `diff src/groundx/values.schema.json helm/values.schema.json` — confirm **no
      output** (byte-identical), matching the repo's manual-mirror convention.
- [x] 3.2 Run `helm lint src/groundx` (no custom values — chart defaults) — confirm it still
      passes, proving the change is additive and does not affect the default configuration.
- [x] 3.3 Run `helm template src/groundx -f src/groundx/values/minikube/values.yaml` (the repo's
      standard render check per `AGENTS.md`) — confirm it still renders cleanly with no
      `layout.inference.pvc` set, proving existing values files are unaffected.
- [x] 3.4 Run `helm unittest src/groundx` (the CI-enforced snapshot gate) — confirm all existing
      snapshots still match. This change touches no template, so no snapshot update is expected;
      if any snapshot changes, that is a signal this change exceeded its scope (schema-only) and
      must be investigated before proceeding.
- [x] 3.5 Delete/discard the scratch values file used in tasks 1 and 2 (never commit throwaway
      test-values files into the repo).

Cross-service coordination: none — this is a single-repo (`groundx-on-prem`), schema-only change
with `contract_roles: INDEPENDENT`. No workspace-level `openspec/changes/<change>/tasks.md`
coordination items apply.
