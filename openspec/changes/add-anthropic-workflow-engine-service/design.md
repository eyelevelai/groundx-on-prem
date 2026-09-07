# Design

## Reuse the existing service shape

`anthropic` is another value of the current service selectors. Summary continues to use
`summary.existing` and `engines.<name>`. Extraction inherits the resolved `default`
summary engine unless `extract.agent.serviceType` explicitly selects another service.
Existing URL, endpoint, engine ID, API-key, existing-secret, and cluster-secret inputs
carry its configuration. No Anthropic-specific values object, secret kind, workload,
or network path is added.

The schema defines `engines.default.service`, while custom engine names are not
property-validated. `config-yaml.yaml` currently reads `serviceType` for every engine.
Render documented `service` first and retain `serviceType` only as a compatibility
fallback. A custom engine that supplies both values currently renders `serviceType`;
after this correction it renders `service`. Record that precedence change in release
notes. This makes the documented field effective without adding a value.

The chart selects configuration only. The matching application image owns native
Messages API transport and response handling.

Anthropic URL values are API roots such as `https://api.anthropic.com/v1`, not the
`/v1/messages` operation endpoint. Cashbot and Internal Arcadia append their native
Messages paths.

## Explicit configuration and defaults

Provider names do not determine generic chart behavior. Resolve every configured
engine once in `groundx.engines`. Each engine uses its own explicit values first, then
the shared `summary.existing` values where it inherits them, then the in-cluster
EyeLevel defaults. The generated default engine is therefore already a complete
self-hosted engine. Summary rendering, local workload selection, and extraction all
consume this same resolved map.

If extraction does not select a service, render the resolved `default` engine's
service, key, URL, model, and reasoning value into `AgentSettings` and its existing
Secret.

If `extract.agent.serviceType` is set, extraction uses its own supplied key, URL,
model, kwargs, and reasoning value instead. Do not fill missing settings from the
summary engine. An explicit local EyeLevel extraction service uses the chart-managed
local endpoint, model, and credential unless those fields are explicitly overridden.
Keep provider-specific branches only where the chart has a real infrastructure
requirement, such as Bedrock image transport requiring S3.

Engine resolution uses non-empty `service`, then non-empty legacy `serviceType`, then
`summary.existing`, then the in-cluster EyeLevel default. String conversion happens
after omission is resolved so an absent value cannot become a non-empty sentinel.
Consumers do not repeat that precedence or infer local settings independently.

Do not replace the existing runtime configuration hierarchy. Cashbot keeps its global
summary defaults and per-engine overrides. The extraction runtime receives the same
resolved default engine at deployment and continues to overlay a workflow engine when
one is supplied. No Cashbot or `config.yaml` contract change is required.

Summary routing and local workload creation are separate decisions. External summary
and inherited extraction use the same external engine and do not require local model
pods. Deploy local summary API and inference pods when a summary engine needs them or
when `extract.agent` explicitly selects the chart-managed local EyeLevel service.

## Credentials

Summary and extraction use their existing credential fields. Inherited extraction uses
the resolved default summary credential. Any explicitly supplied extraction API key is
rendered regardless of service name. An explicit external extraction service without a
key is rendered without a key. Helm does not decide whether that provider or
self-hosted service requires authentication.

Templates and tests must not print credential values. This change adds no secret data,
secret name, or environment variable.

## Source and mirror

Base the plan and implementation on current pushed `origin/0.2.7`, the active chart
release line. Do not use `origin/main` as the base: its chart templates, schema, and
validation script have diverged from the release line. Implement in `src/groundx`
first. Regenerate snapshots through Helm tooling, then copy the matching changed source
files into `helm` because that directory is the manually maintained published mirror.
Compare both surfaces after synchronization.

## Deployment

Merge after the Fern service contract and Cashbot runtime behavior are settled. A chart
may be released only with application image versions that understand native Anthropic.
Canary one text summary and one multimodal extraction-agent request using existing
secret handling before production assignment.

No stateful migration or zero-downtime coordination is required. Anthropic failures
affect opted-in model calls; the per-engine precedence correction can also affect a
non-Anthropic custom engine that sets `service`, especially when it also sets
`serviceType`. Rollback restores the prior chart, service selection, or image while
leaving stored `anthropic` values readable upstream.

## Validation

Add render tests for summary and extraction-agent paths covering Anthropic, Bedrock,
OpenAI, custom hosted, custom self-hosted, and omitted-service defaults. Prove
extraction inherits the resolved default summary engine, an explicit extraction engine
wins, local defaults do not leak into explicit external services, required local
workloads remain available, missing keys do not fail chart rendering, and documented
`service` wins over legacy `serviceType`.
Run the full Helm gate, a normal minikube render, strict OpenSpec validation, mirror
comparison, and `git diff --check`.
