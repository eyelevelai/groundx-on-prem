# Design

## Reuse the existing service shape

`anthropic` is another value of the current service selectors. Summary continues to use
`summary.existing` and `engines.<name>`; extraction agents continue to use
`extract.agent`. Existing URL, endpoint, engine ID, API-key, existing-secret, and
cluster-secret inputs carry its configuration. No Anthropic-specific values object,
secret kind, workload, or network path is added.

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

Provider names do not determine generic chart behavior. If a summary engine or
extraction agent explicitly sets a service, render that exact service and every
supplied key, URL, model, kwarg, and reasoning value. Do not add in-cluster endpoint,
model, key, kwargs, or reasoning defaults. This applies equally to Anthropic, Bedrock,
OpenAI-compatible, custom hosted, and custom self-hosted services.

Only an omitted service selects the in-cluster EyeLevel default and its GroundX admin
key, endpoint, model, kwargs, and reasoning settings. Keep provider-specific branches
only where the chart has a real infrastructure requirement, such as Bedrock image
transport requiring S3.

Summary workload creation must use the same existing service precedence as rendered
summary configuration: non-empty `service`, then non-empty legacy `serviceType`, then
`summary.existing`, then the in-cluster EyeLevel default. String conversion must happen
after omission has been resolved so an absent value cannot become a non-empty sentinel.

Do not replace the existing runtime configuration hierarchy. Cashbot keeps its global
summary defaults and per-engine overrides. `extract.agent` remains the extraction
deployment default, and the extraction runtime continues to overlay workflow engine
settings when a workflow supplies them. No Cashbot or `config.yaml` contract change is
required.

## Credentials

Summary and extraction use their existing credential fields. Any explicitly supplied
API key is rendered, regardless of service name. An explicit service without a key is
also rendered without a key. Helm does not decide whether that provider or self-hosted
service requires authentication. It never substitutes `admin.apiKey` for an explicitly
configured service.

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
OpenAI, custom hosted, custom self-hosted, and omitted-service defaults. Prove explicit
values pass through, local defaults do not leak into explicit services, an engine ID
without a service keeps local summary workloads, missing keys do not fail chart
rendering, and documented `service` wins over legacy `serviceType`.
Run the full Helm gate, a normal minikube render, strict OpenSpec validation, mirror
comparison, and `git diff --check`.
