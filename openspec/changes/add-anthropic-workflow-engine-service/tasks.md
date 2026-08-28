# Anthropic workflow engine service implementation plan

## 1. Lock current failure with render tests

- [ ] 1.1 Add failing summary tests showing `anthropic` is currently classified as
  in-cluster and can inherit the wrong endpoint or credential.
- [ ] 1.2 Add a failing render test proving the schema-supported
  `engines.<name>.service` field is currently ignored, plus one custom non-default
  engine case proving legacy `serviceType` currently wins when both values disagree.
- [ ] 1.3 Add failing extraction-agent tests for endpoint, model, kwargs, reasoning,
  exact service value, and credential selection.
- [ ] 1.4 Add failure cases for missing effective Anthropic endpoint, engine ID or
  model, and credential.

## 2. Extend the existing service selectors

- [ ] 2.1 Add exact `anthropic` to the external-service checks in the authoritative
  `src/groundx` summary and extraction-agent helpers.
- [ ] 2.2 Render the existing `engines.<name>.service` schema field, retaining
  `serviceType` only as a compatibility fallback. Prove documented `service` wins when
  a custom engine supplies both values; add no separate `serviceType`-only fixture.
- [ ] 2.3 Reuse existing URL, endpoint, engine, model, and credential fields. Add no
  values or schema properties.
- [ ] 2.4 Require effective Anthropic credentials and prevent `admin.apiKey` fallback.
- [ ] 2.5 Preserve every existing provider branch and unknown-service behavior.

## 3. Synchronize generated and published surfaces

- [ ] 3.1 Regenerate affected Helm unit snapshots. Do not edit snapshots manually.
- [ ] 3.2 Copy the matching changed source templates and contract files into the
  published `helm` mirror and compare both surfaces.
- [ ] 3.3 Update concise values guidance for the existing fields without adding
  credentials or a second configuration shape. Add a release note that per-engine
  `service` now takes effect and wins over legacy `serviceType` when both are present.

## 4. Validate and release safely

- [ ] 4.1 Run `.build/bin/validate-helm.sh`, `helm template src/groundx -f
  src/groundx/values/minikube/values.yaml`, strict OpenSpec validation, and `git diff
  --check`.
- [ ] 4.2 Record the Fern and Cashbot prerequisite versions and the immutable application
  images that support native Anthropic.
- [ ] 4.3 Canary one text summary and one multimodal extraction-agent request with no
  credential values in evidence.
- [ ] 4.4 Roll out Anthropic only to opted-in environments. Before chart release,
  identify any non-Anthropic custom-engine values that set `service` or both service
  keys, review the rendered precedence change, and include it in the upgrade notes.
  Roll back the chart, provider assignment, or runtime image without removing the
  additive service value.
