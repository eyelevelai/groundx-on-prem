# Expose Extract Terminal Agent Trace Tasks

## 1. Values Contract

- [x] Add the shared default to `src/groundx/values.yaml`.
- [x] Add strict shared and pod boolean fields to
      `src/groundx/values.schema.json`.
- [x] Do not add pod defaults, because omission means inheritance.

## 2. Pod Helpers

- [x] Add presence-aware effective-value helpers to the API, agent, download,
      and save `.tpl` files.
- [x] Add the effective environment value to each pod settings map.
- [x] Preserve the agent's existing environment entries.
- [x] Add settings environment rendering to the shared API deployment template.

## 3. Tests

- [x] Prove the default is `false` on all four extract deployments.
- [x] Prove shared `true` reaches all four deployments.
- [x] Prove pod `false` overrides shared `true`.
- [x] Prove pod `true` overrides shared `false`.
- [x] Prove non-boolean values fail schema validation.
- [x] Regenerate snapshots through `helm unittest -u`; do not edit them by hand.

## 4. Published Mirror

- [x] Mirror changed source chart files into `helm/`.
- [x] Confirm source and mirror files match.

## 5. Documentation

- [x] Document the shared value, pod overrides, precedence, and default.
- [x] Link the compatible Internal Arcadia AGE-272 runtime and rollout contract.

## 6. Validation

- [x] Run `.build/bin/validate-helm.sh --junit`.
- [x] Run strict OpenSpec validation.
- [x] Run `git diff --check`.
- [x] Review the rendered manifest diff for unrelated changes.

## 7. Runtime Handoff

- [x] Confirm the compatible Internal Arcadia image uses the setting in API,
      agent, download, and save terminal failure owners.
- [x] Confirm API failure diagnostics use one best-effort one-second transport
      budget, preserve response status and body, and make no hard wall-clock
      guarantee.
- [x] Confirm download, agent, and save write no terminal artifact or processing
      terminal record while callback publication can retry or requeue the task.
- [x] Leave deployment and enablement to the existing AGE-272 storage, budget,
      security, readiness, and natural-failure gates.
- [x] Do not deploy or publish from this chart implementation plan.
