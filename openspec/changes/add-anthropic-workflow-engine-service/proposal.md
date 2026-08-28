# Add Anthropic to the existing external engine configuration

## Why

The shared workflow contract will add `service: anthropic`. The chart currently treats
that value as an in-cluster summary or extraction agent service, substitutes internal
defaults, and can fall back to the GroundX admin key. Its schema also calls the
per-engine field `service`, while the renderer reads `serviceType`. That does not
configure a native Anthropic runtime safely.

## Blast Radius

Only deployments that select `anthropic` for `summary.existing.serviceType` or
`extract.agent.serviceType` change. Existing service selections, Kubernetes resources,
stateful services, queues, and default deployments remain unchanged. Enabling Anthropic
changes outbound model traffic and requires an Anthropic endpoint, model, and credential.

## What Changes

- Recognize exact `anthropic` as an external provider in the existing summary and
  extraction-agent service selectors. Render the schema's existing per-engine
  `service` field instead of silently ignoring it.
- Reuse summary's existing URL, API key, and per-engine fields, plus the extraction
  agent's existing endpoint, model, API key, existing-secret, and cluster-secret
  configuration. Add no chart value.
- Require an explicit Anthropic credential source. Never substitute the GroundX admin
  API key.
- Prevent in-cluster endpoint, model, kwargs, and reasoning defaults from being applied
  to Anthropic.
- Keep `src/groundx` authoritative and synchronize the matching published `helm` mirror.

## Capabilities

### New Capabilities

- `anthropic-workflow-engine-service`: the chart can configure existing summary and
  extraction-agent workloads for a runtime image that natively supports Anthropic.

### Modified Capabilities

None.

## Impact

- Templates: summary and extraction-agent provider classification, validation,
  per-engine service rendering, and credential selection.
- Values contract: no new or renamed field.
- Images: no application image is built here. A chart release is blocked until its
  referenced runtime images support native Anthropic.
- Environments: dev, staging, and production only when an operator opts into
  `anthropic`.
- Data and stateful resources: none.
- Rollout: render and canary with a matching immutable runtime image before production.
  Roll back by restoring the prior service selection and secret while keeping the
  additive public enum readable.
- Open design questions: none.
