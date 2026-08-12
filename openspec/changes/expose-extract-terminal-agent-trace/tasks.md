# Expose Extract Terminal Agent Trace Tasks

## 1. Values Contract

- [ ] Add the shared default to `src/groundx/values.yaml`.
- [ ] Add strict shared and pod boolean fields to
      `src/groundx/values.schema.json`.
- [ ] Do not add pod defaults, because omission means inheritance.

## 2. Pod Helpers

- [ ] Add presence-aware effective-value helpers to the API, agent, download,
      and save `.tpl` files.
- [ ] Add the effective environment value to each pod settings map.
- [ ] Preserve the agent's existing environment entries.
- [ ] Add settings environment rendering to the shared API deployment template.

## 3. Tests

- [ ] Prove the default is `false` on all four extract deployments.
- [ ] Prove shared `true` reaches all four deployments.
- [ ] Prove pod `false` overrides shared `true`.
- [ ] Prove pod `true` overrides shared `false`.
- [ ] Prove non-boolean values fail schema validation.
- [ ] Regenerate snapshots through `helm unittest -u`; do not edit them by hand.

## 4. Published Mirror

- [ ] Mirror changed source chart files into `helm/`.
- [ ] Confirm source and mirror files match.

## 5. Documentation

- [ ] Document the shared value, pod overrides, precedence, and default.
- [ ] Link the compatible Internal Arcadia AGE-272 runtime and rollout contract.

## 6. Validation

- [ ] Run `.build/bin/validate-helm.sh --junit`.
- [ ] Run strict OpenSpec validation.
- [ ] Run `git diff --check`.
- [ ] Review the rendered manifest diff for unrelated changes.

## 7. Runtime Handoff

- [ ] Confirm the compatible Internal Arcadia image uses the setting in API,
      agent, download, and save terminal failure owners.
- [ ] Confirm API failure diagnostics have one absolute one-second deadline and
      preserve response status and body.
- [ ] Confirm download, agent, and save write no terminal artifact or processing
      terminal record while callback publication can retry or requeue the task.
- [ ] Leave deployment and enablement to the existing AGE-272 storage, budget,
      security, readiness, and natural-failure gates.
- [ ] Do not deploy or publish from this chart implementation plan.
