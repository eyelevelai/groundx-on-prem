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
- [x] 1.4 Add cases proving a missing provider key does not fail Helm rendering or
  inherit the GroundX admin key.
- [x] 1.5 Add a regression case proving an engine ID without a service keeps the local
  summary API and inference workloads.

## 2. Replace provider allowlists with explicit configuration

- [x] 2.1 Use explicit service presence, rather than a provider-name allowlist, to
  choose between supplied configuration and local defaults.
- [x] 2.2 Render the existing `engines.<name>.service` schema field, retaining
  `serviceType` only as a compatibility fallback. Prove documented `service` wins when
  a custom engine supplies both values; add no separate `serviceType`-only fixture.
- [x] 2.3 Reuse existing URL, endpoint, engine, model, and credential fields. Add no
  values or schema properties.
- [x] 2.4 Render any explicitly supplied key and never substitute `admin.apiKey` for an
  explicit service. Do not require provider authentication in Helm.
- [x] 2.5 Render any explicit extraction service into `AgentSettings`, including custom
  hosted and self-hosted values.
- [x] 2.6 Preserve omitted-service defaults and Bedrock's S3 infrastructure check.
- [x] 2.7 Make extraction inherit the resolved default summary engine when no
  extraction service is selected.
- [x] 2.8 Keep explicit extraction settings authoritative and deploy local model
  workloads when an explicit local extraction engine needs them.
- [x] 2.9 Resolve configured and generated engines once, then use that resolved map for
  summary rendering, local workload selection, and inherited extraction settings.
- [x] 2.10 Resolve the effective extraction engine once, then make extraction field
  helpers and local workload selection read that resolved map.
- [x] 2.11 Use the chart's settings, existing, and create helper conventions; share
  the engine format and local-pod decision, and validate engines in their builder.
- [x] 2.12 Remove the extraction file settings forwarding layer and share file URL,
  TLS, and port parsing. Preserve account inheritance, explicit empty credentials,
  upload configuration, and local storage wait addresses without adding schema fields.

## 3. Synchronize generated and published surfaces

- [x] 3.1 Regenerate affected Helm unit snapshots. Do not edit snapshots manually.
- [x] 3.2 Copy the matching changed source templates and contract files into the
  published `helm` mirror and compare both surfaces.
- [x] 3.3 Update concise values guidance for the existing fields without adding
  credentials or a second configuration shape. Add a release note that per-engine
  `service` now takes effect and wins over legacy `serviceType` when both are present.
- [x] 3.4 Document and test Anthropic URL values as API roots ending at `/v1`; do not
  configure the `/v1/messages` operation path because each native runtime appends it.

## 4. Validate and release safely

- [x] 4.1 Run `.build/bin/validate-helm.sh`, `helm template src/groundx -f
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
