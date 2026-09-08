# Add Anthropic to the existing external engine configuration

## Why

The shared workflow contract adds `service: anthropic`. The chart currently uses
provider-name allowlists to decide whether an explicitly configured service receives
its own values or inherits in-cluster defaults. It also calls the per-engine field
`service` while the renderer reads `serviceType`. Explicit engine configuration must
be passed through without provider-specific chart policy.

## Blast Radius

Any explicitly configured summary or extraction service keeps its supplied service,
key, URL, model, kwargs, and reasoning values. Extraction inherits the resolved
default summary engine unless `extract.agent` explicitly selects its own service. The
documented per-engine `service` becomes authoritative over legacy `serviceType`.

## What Changes

- Render any explicitly configured service and its existing settings unchanged.
- Use the resolved default summary engine for extraction when no extraction service is
  selected.
- Keep `extract.agent` as the explicit extraction override.
- For an explicitly selected external service, render its key when supplied and leave
  it unset otherwise. Keep the existing local service credential default.
- Keep only infrastructure-specific validation, such as Bedrock requiring S3.
- Render the schema's existing per-engine `service` field instead of silently ignoring
  it. Add no chart value.
- Keep `src/groundx` authoritative and synchronize the matching published `helm` mirror.

## Capabilities

### New Capabilities

- `anthropic-workflow-engine-service`: the chart can configure existing summary and
  extraction-agent workloads for a runtime image that natively supports Anthropic.

### Modified Capabilities

None.

## Impact

- Branch: base the plan and implementation on current pushed `origin/0.2.7`, the active
  chart release line. Do not carry `origin/main` history or validate against its older
  chart and CI surfaces.
- Templates: shared default-engine selection, extraction-agent override selection,
  per-engine service rendering, and credential pass-through.
- Values contract: no new or renamed field.
- Images: no application image is built here. A chart release is blocked until its
  referenced runtime images support native Anthropic.
- Environments: dev, staging, and production when an operator opts into `anthropic` or
  already supplies per-engine `service`; conflicting custom-engine values follow the
  documented `service` field after upgrade.
- Data and stateful resources: none.
- Rollout: render and canary with a matching immutable runtime image before production.
  Release notes call out the per-engine precedence correction. Roll back by restoring
  the prior chart or service selection and secret while keeping the additive public
  enum readable.
- Open design questions: none.
