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
- [ ] State that only compatible runtime paths act on the setting.

## 6. Validation

- [ ] Run `.build/bin/validate-helm.sh --junit`.
- [ ] Run strict OpenSpec validation.
- [ ] Run `git diff --check`.
- [ ] Review the rendered manifest diff for unrelated changes.

## 7. Rollout

- [ ] Deploy with the shared default `false` and verify all extract workloads.
- [ ] Enable the shared setting or selected pod overrides through Helm.
- [ ] Verify each deployment receives its intended effective value.
- [ ] Verify terminal agent artifact behavior with a compatible extract image.
