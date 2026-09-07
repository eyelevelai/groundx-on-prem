# Anthropic workflow engine service implementation plan

## Global constraints

- Base the plan and implementation on current pushed `origin/0.2.7` in an isolated
  worktree. Carry only this OpenSpec change and its eventual implementation; do not
  include `origin/main`-only commits.

## 1. Lock current failure with render tests

- [x] 1.1 Add failing summary tests showing an explicit service can inherit the wrong
  in-cluster endpoint or credential.
- [x] 1.2 Add a failing render test proving the schema-supported
  `engines.<name>.service` field is currently ignored, plus one custom non-default
  engine case proving legacy `serviceType` currently wins when both values disagree.
- [x] 1.3 Add failing extraction-agent tests for explicit endpoint, model, kwargs,
  reasoning, service value, and credential pass-through.
- [ ] 1.4 Prove a missing provider key does not fail Helm rendering or inherit the
  GroundX admin key after the rendered configuration is loaded by Cashbot.
- [ ] 1.5 Add the local, global, explicit, mixed, extraction-independent, and explicit
  empty-value matrix from the design. Verify both rendered settings and local workload
  counts.

## 2. Replace provider allowlists with explicit configuration

- [ ] 2.1 Use explicit service presence, rather than a provider-name allowlist, to
  choose between supplied configuration and local defaults.
- [x] 2.2 Render the existing `engines.<name>.service` schema field, retaining
  `serviceType` only as a compatibility fallback. Prove documented `service` wins when
  a custom engine supplies both values; add no separate `serviceType`-only fixture.
- [x] 2.3 Reuse existing URL, endpoint, engine, model, and credential fields. Add no
  values or schema properties.
- [ ] 2.4 Render any explicitly supplied key and never substitute `admin.apiKey` for an
  explicit service. Do not require provider authentication in Helm.
- [x] 2.5 Render any explicit extraction service into `AgentSettings`, including custom
  hosted and self-hosted values.
- [ ] 2.6 Preserve omitted-service defaults and Bedrock's S3 infrastructure check.
- [ ] 2.7 Add one reusable, presence-aware model resolver. Use its result for summary
  workload creation, validation, and configuration rendering. Use the same resolution
  contract for extraction through its existing adapter.
- [ ] 2.8 Include extraction in the local-workload decision. An enabled extraction agent
  without an explicit service keeps local summary API and inference workloads deployed.
- [ ] 2.9 Preserve explicit empty values and keep summary and extraction settings
  independent.

## 3. Preserve the runtime engine boundary

- [ ] 3.1 Update the existing Cashbot engine initializer so an explicit service does not
  inherit a global key or URL. Keep the legacy fallback when service is absent.
- [ ] 3.2 When named engines exist, render resolved credentials and endpoints on their
  owning engines rather than using one global provider fallback.
- [ ] 3.3 Load chart-rendered local, external, keyless, inherited, and mixed
  configurations through the production Cashbot loader and engine initializer. Assert
  each engine's final service, key, and URL without logging secret values.

## 4. Synchronize generated and published surfaces

- [ ] 4.1 Regenerate affected Helm unit snapshots. Do not edit snapshots manually.
- [ ] 4.2 Copy the matching changed source templates and contract files into the
  published `helm` mirror and compare both surfaces.
- [ ] 4.3 Update concise values guidance for the existing fields without adding
  credentials or a second configuration shape. Add a release note that per-engine
  `service` now takes effect and wins over legacy `serviceType` when both are present.
- [x] 4.4 Document and test Anthropic URL values as API roots ending at `/v1`; do not
  configure the `/v1/messages` operation path because each native runtime appends it.

## 5. Validate and release safely

- [ ] 5.1 Run `.build/bin/validate-helm.sh`, `helm template src/groundx -f
  src/groundx/values/minikube/values.yaml`, strict OpenSpec validation, and `git diff
  --check`. Run the Cashbot runtime matrix and compare the source and published mirror.
- [ ] 5.2 Record the Fern and Cashbot prerequisite versions and the immutable application
  images that support native Anthropic.
- [ ] 5.3 Canary one text summary and one multimodal extraction-agent request with no
  credential values in evidence.
- [ ] 5.4 Roll out Anthropic only to opted-in environments. Before chart release,
  identify any non-Anthropic custom-engine values that set `service` or both service
  keys, review the rendered precedence change, and include it in the upgrade notes.
  Roll back the chart, provider assignment, or runtime image without removing the
  additive service value.
