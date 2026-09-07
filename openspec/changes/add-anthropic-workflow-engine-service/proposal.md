# Add Anthropic to the existing external engine configuration

## Why

The shared workflow contract adds `service: anthropic`. The chart currently uses
provider-name allowlists to decide whether an explicitly configured service receives
its own values or inherits in-cluster defaults. It also calls the per-engine field
`service` while the renderer reads `serviceType`. Explicit engine configuration must
be passed through without provider-specific chart policy. The chart also resolves
summary settings in more than one template, and Cashbot applies global key and URL
defaults after Helm renders the configuration. Those separate decisions can remove a
required local model or attach local credentials to an explicit external engine.

## Blast Radius

Any explicitly configured summary or extraction service now keeps its supplied
service, key, URL, model, kwargs, and reasoning values without inheriting local
GroundX settings. The documented per-engine `service` becomes authoritative over
legacy `serviceType`. Configurations that omit the service retain existing local
defaults. Summary and extraction keep separate configuration inputs, but use one
presence-based resolution contract. Any resolved local consumer keeps the chart-managed
summary workloads enabled.

## What Changes

- Render any explicitly configured service and its existing settings unchanged.
- Resolve configured values and defaults once, then reuse that result for workload
  creation, validation, and rendered configuration.
- Use in-cluster endpoint, model, key, kwargs, and reasoning defaults only when the
  service is omitted.
- Do not make provider authentication policy in Helm. Render an explicit key when
  supplied and otherwise leave it unset.
- Keep `engines.<name>` and `extract.agent` independent. An explicit extraction model
  never inherits a summary engine's settings.
- Keep local summary workloads when either a summary engine or the extraction agent
  resolves to the chart-managed local model.
- Make Cashbot preserve the resolved per-engine boundary instead of applying a global
  key or URL to an explicitly configured engine.
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
- Templates: shared model resolution, local-workload selection, summary and
  extraction-agent adapters, per-engine service rendering, and credential pass-through.
- Runtime dependency: Cashbot must not apply global credentials or endpoints to an
  engine whose service is explicit. Test the rendered chart configuration through the
  production Cashbot loader and engine initializer.
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
