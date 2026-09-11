# Design

Add `integration.extractionCaptureAccounts` to `values.yaml` and the strict
values schema. Render the list directly under
`integrationTests.extractionCaptureAccounts` in the shared GroundX
`config.yaml`. Omit the runtime key when the default list is empty so current
rendered configuration and authorization remain unchanged.

Implement in `src/groundx` first, then copy the same values, schema, and
template changes to the published `helm` mirror. A focused Helm unit test proves
the default and configured render. Schema checks prove invalid values fail.

The shared ConfigMap hash can roll enabled Go services and metrics. Deploy one
production Helm revision with the approved internal testing account, wait for
rollout completion, verify the exact rendered list, and confirm no unrelated
manifest drift. The hosted GroundX API is a Cashbot Lambda outside this chart;
when certification uses that endpoint, update its production config and deploy
it through Cashbot's release path as a separate step. Roll back each surface
through its owning deployment. No stateful resource changes or migrations occur.
