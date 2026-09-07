# Design

## Configuration surfaces

`anthropic` is another value of the current service selectors. Summary keeps
`summary.existing` and `engines.<name>`. Extraction keeps `extract.agent` because it is
a separately deployed Python consumer with its own model, endpoint, options, and
credential delivery. No Anthropic-specific values object, secret kind, workload, or
network path is added.

The two surfaces use the same resolution rules. They do not inherit settings from each
other. Summary resolves each named engine. Extraction resolves its single deployment
default. Separate adapters render the result into Cashbot `config.yaml` and Python
`AgentSettings`.

The schema defines `engines.default.service`, while the renderer historically read
`serviceType`. Non-empty `service` is authoritative. Non-empty `serviceType` is only a
compatibility fallback. Record that precedence change in release notes.

Anthropic URLs are API roots such as `https://api.anthropic.com/v1`, not the
`/v1/messages` operation endpoint. Cashbot and Internal Arcadia append their native
Messages paths.

## One model resolver

Use one reusable, presence-aware model resolver. It accepts configured values and a
fallback and returns the effective service, key, URL, model, options, reasoning value,
and whether the chart-managed local summary service is required. It must preserve the
difference between an omitted property and a property explicitly set to an empty value.
For backward compatibility, an empty `service` or `serviceType` means the service is
omitted. Explicit empty keys, URLs, models, options, and reasoning values remain empty.

Apply these rules in order:

1. An explicitly supplied field wins, regardless of service name.
2. An explicitly empty field stays empty.
3. A summary engine with no service inherits `summary.existing` when that configuration
   exists.
4. A summary engine with neither an engine service nor `summary.existing` uses the
   chart-managed EyeLevel defaults.
5. An extraction agent with an explicit `extract.agent.serviceType` uses only its
   extraction-agent settings. Missing provider values remain missing.
6. An extraction agent without `serviceType` uses the chart-managed EyeLevel defaults.
   It does not inherit a summary engine or `summary.existing` provider.
7. An effective `eyelevel` service without an explicit or inherited URL selects the
   chart-managed local service. An explicit URL selects that endpoint and does not
   require chart-managed summary pods.
8. No other explicit service receives a local key, endpoint, model, options, or
   reasoning default.

Provider names do not control authentication. Keep service-specific branches only for
real infrastructure behavior: `eyelevel` identifies the chart-managed workload, and
Bedrock image transport requires S3.

## Local workload decision

Decide once after resolving both surfaces. Deploy local summary API and inference pods
when any summary engine requires them, or when extraction is enabled and its resolved
model is local. An explicit external summary engine must not disable local pods still
needed by extraction. An explicit external extraction model must not start local pods
unless a summary engine needs them. Determine locality from the resolved service and
URL source, not from the service name alone.

The current `summary.create` and `config-yaml.yaml` calculations must not independently
reconstruct service or default choices. Both consume the same resolved result.

## Runtime boundary

Cashbot currently accepts global key and URL defaults and then copies them into an
engine when its fields are empty. That can attach a local GroundX credential and URL to
an explicit external service after Helm has rendered a keyless engine.

When named engines exist, materialize the resolved key and URL on the engines that own
them. Do not use one global provider credential as their shared fallback. Retain the
legacy global configuration only for the legacy path without named engines.

The Cashbot engine initializer must also preserve the explicit-service boundary:

- If the service is explicit, start with an empty key and URL, then apply only the
  engine's resolved values.
- If the service is absent on a legacy input, retain the existing global fallback.

This is a generic runtime rule, not an Anthropic branch. It protects every external,
hosted, and self-hosted service from unrelated global defaults.

## Credentials

Summary and extraction retain their existing credential fields and secret delivery.
Render any explicitly supplied key regardless of service name. A configured existing
secret or cluster secret is mounted because it was configured, not because Helm knows
the provider. Do not require a key in Helm. Do not print credential values in tests or
evidence.

## Source and mirror

Base implementation on current pushed `origin/0.2.7`, the active chart release line.
Implement in `src/groundx` first. Regenerate snapshots through Helm tooling, then copy
matching source templates and contract files into the manually maintained `helm`
mirror. Compare both surfaces after synchronization.

## Deployment

Merge after the Fern service contract and Cashbot runtime behavior are settled. Release
only with application images that understand native Anthropic and the resolved-engine
contract. Canary one text summary and one multimodal extraction-agent request using
existing secret handling before production assignment.

No stateful migration is required. Rollback restores the prior chart, service selection,
or image while leaving the additive public service value readable upstream.

## Validation

Test the complete input matrix: legacy configuration, engine ID without service,
`summary.existing` inheritance, explicit local service, explicit external service,
keyless external service, mixed local and external engines, independent extraction
configuration, explicit empty values, and `service` versus `serviceType` precedence.

Helm assertions alone are insufficient. Render the chart configuration, load it through
the production Cashbot configuration loader and engine initializer, and verify each
engine's final service, key, and URL. Verify local pod counts from the same cases. Run
the full Helm gate, normal minikube render, strict OpenSpec validation, source-to-mirror
comparison, Cashbot tests, and `git diff --check`.
