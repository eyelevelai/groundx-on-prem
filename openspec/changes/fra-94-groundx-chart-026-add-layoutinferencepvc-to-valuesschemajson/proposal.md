## Why

Chart 0.2.6's `values.schema.json` omits `pvc` from `groundx.layout.inference.properties`
(`groundx.ranker.inference` has it) and `layout.inference` sets `additionalProperties: false`, so
setting `layout.inference.pvc` fails schema validation at render/sync time even though the chart
template already fully implements it (`templates/_helpers/app/layout-inference.tpl`,
`templates/app/inference.yaml`). This blocks switching `layout-inference` from its single AZ-locked
RWO EBS volume to the same EFS-RWX shared-model pattern `ranker-inference` already uses — the only
thing standing between `layout-inference` and running 2 replicas across its 2 provisioned
`gpu-layout` T4 nodes instead of 1. A 2026-07-21 load test (bucket 28, 548 documents, ~2h17m) showed
the 1 active replica pinned at 99-100% GPU for ~21 minutes while the 2nd T4 sat at 0% the entire run
— fully paid-for compute doing nothing. Fixing the schema unblocks ~2x layout element-detection
throughput at $0 additional infra cost.

## What Changes

- Add a `pvc` property block to `groundx.layout.inference.properties` in
  `src/groundx/values.schema.json` (the authoritative source), mirroring
  `groundx.ranker.inference.pvc` **verbatim**: an object with properties `access`, `capacity`,
  `class`, `name` (all `type: string`) and `additionalProperties: false`, inserted alphabetically
  between the existing `nodeSelector` and `queue` keys.
- Hand-mirror the identical `pvc` block into `helm/values.schema.json` so the two files stay
  byte-identical, per the repo's manual-mirror convention (`helm/` has no regen guard — AGENTS.md).
- No other schema keys, chart templates, `Chart.yaml` version, or publish step change. The template
  side of `layout.inference.pvc` is already implemented and correct; this is a **schema-permission
  fix only** — it makes an already-supported configuration legal, it does not add new rendering
  behavior.

## Capabilities

### New Capabilities
- `layout-inference-pvc`: the values-schema requirement that `groundx.layout.inference` accepts a
  `pvc` object (`access`, `capacity`, `class`, `name`) with the same shape already accepted under
  `groundx.ranker.inference.pvc`, so operators can configure a PVC (e.g. EFS-RWX) for
  `layout-inference` without `helm lint`/`helm template`/render-time schema validation rejecting it.

### Modified Capabilities
(none — no existing `openspec/specs/` capability covers `values.schema.json`'s `pvc` shape; the
only existing layout-inference capability, `layout-inference-cpu-resources`, covers unrelated
GPU/CPU resource-key rendering, not schema-level property permissions.)

## Impact

- **Affected files:** `src/groundx/values.schema.json` (authoritative edit) and
  `helm/values.schema.json` (manual mirror edit) only.
- **Blast radius:** additive and narrow. Today `layout.inference.pvc` is universally rejected by
  schema validation, so no existing install can be setting it — this change can only newly *permit*
  a previously-impossible configuration; it does not alter validation or rendering for any values
  file that doesn't set `layout.inference.pvc`. No template, default-value, or replica-count change
  ships with this proposal — enabling the actual EFS-RWX cutover and replica-count bump is a
  separate, later change that this schema fix unblocks.
- **Environments:** dev/staging/prod all currently reject `layout.inference.pvc`; all three become
  able to accept it once this ships. No environment is forced to change its values — the fix is
  opt-in per the operator's own values file.
- **Data / stateful resources:** none created, deleted, or mutated by this change itself — it only
  changes what the JSON Schema permits. Any actual PVC/EFS provisioning happens later, when an
  operator sets `layout.inference.pvc` in their values and runs their own `helm upgrade`.
- **Rollback:** revert both schema files. Any values file that had started setting
  `layout.inference.pvc` would again fail schema validation — that is the pre-change behavior, so
  rollback is safe and has no data-loss implication.
- **Privileged operations:** none. No `bin/operator`, `bin/environment`, or `src/build.sh` (chart
  publish) is run as part of this change; `Chart.yaml`'s version (0.2.7) is unchanged by this
  proposal.
- **Open design questions:** none — the fix is a verbatim mirror of an existing, working schema
  block into a sibling block that's missing it; no brainstorming needed.
