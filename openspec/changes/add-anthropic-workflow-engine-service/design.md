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

## Provider classification

Add exact `anthropic` wherever summary or extraction-agent templates distinguish an
external model service from the in-cluster EyeLevel service. For Anthropic:

- render the operator-supplied summary URL or per-engine base URL and engine ID, and
  the extraction-agent endpoint and model;
- do not synthesize the in-cluster summary endpoint or model;
- do not inject local-model kwargs or reasoning defaults; and
- preserve the exact lowercase service value in generated application configuration.

Other service values keep their current behavior except for the explicit per-engine
`service` precedence correction above.

## Credentials

Anthropic must use the existing provider credential paths. Summary accepts
`summary.existing.apiKey` as its baseline or an `engines.<name>.apiKey` override.
Extraction accepts its existing `apiKey`, `existingSecret`, or `cluster.secrets`
source. Missing effective Anthropic credentials fail chart validation instead of using
`admin.apiKey`.

Templates and tests must not print credential values. This change adds no secret data,
secret name, or environment variable.

## Source and mirror

Implement in `src/groundx` first. Regenerate snapshots through Helm tooling, then copy
the matching changed source files into `helm` because that directory is the manually
maintained published mirror. Compare both surfaces after synchronization.

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

Add render and failure tests for both summary and extraction-agent paths, including
credential sources and absent required configuration. Add one custom-engine case with
conflicting `service` and `serviceType` values and prove documented `service` wins; do
not add a separate legacy-only fixture. Run the full Helm gate, a normal minikube
render, strict OpenSpec validation, mirror comparison, and `git diff --check`.
