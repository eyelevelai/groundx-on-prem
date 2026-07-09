# Expose Document Summary Image Limit Tasks

## 1. Discovery

- [x] Re-read `AGENTS.md` and `openspec/config.yaml`.
- [x] Re-read GroundX Studio Harness on-prem values references.
- [x] Re-read the `cashbot-go` OpenSpec change
      `limit-doc-summary-page-images`.
- [x] Confirm the target app config key is `engines.default.maxImages`.
- [x] Confirm current chart rendering omits `maxImages`.

### Review Checkpoint 1

- [x] Confirm this chart change is config exposure only.
- [x] Confirm no Kubernetes workload shape or stateful resource changes are
      needed.

## 2. Update Source Chart

- [x] Add `maxImages` to `src/groundx/values.schema.json` under
      `engines.default`.
- [x] Render `maxImages` in
      `src/groundx/templates/resources/config-yaml.yaml` when present.
- [x] Do not add a chart default; the app runtime owns the default of 30.
- [x] Add or update values comments/examples only if the repo has a nearby
      pattern for engine field documentation.

### Review Checkpoint 2

- [x] Confirm schema validation accepts the new field.
- [x] Confirm rendered app `config.yaml` contains `maxImages`.

## 3. Mirror Published Chart Files

- [x] Mirror the same source chart changes into `helm/`.
- [x] Do not hand-edit generated snapshot files.
- [x] Review `src/groundx` versus `helm/` for accidental drift.

### Review Checkpoint 3

- [x] Confirm `helm/` is synced for the changed files.
- [x] Confirm existing unrelated dirty `Chart.yaml` changes were not modified.

## 4. Validate

- [x] Run `helm lint src/groundx`.
- [x] Run `helm template src/groundx -f src/groundx/values/minikube/values.yaml`.
- [x] Run `helm unittest src/groundx`.
- [x] Run `OPENSPEC_TELEMETRY=0 npx --yes @fission-ai/openspec@1.3.1 validate --all --strict --json`.
- [x] Run `git diff --check`.
- [x] If snapshots change, regenerate with `helm unittest -u src/groundx`.
- [ ] Include command outputs in the final implementation handoff.

## 5. Rollout Notes

- [x] State that this chart change requires a compatible `cashbot-go` image to
      affect runtime behavior.
- [ ] Roll out to non-production self-hosted environment before production.
- [ ] Confirm running config includes `engines.default.maxImages`.
- [ ] Confirm app logs show selected image count for a long document.
