## Why

`src/groundx/values/values.aws.services.yaml` tells operators that the queue visibility timeout
"must be 10+ min for all SQS queues". GX-63 makes the upload consumer hold in-flight messages for
5 minutes (renewed every minute) so a crashed upload worker's messages become visible again
sooner. The note would then contradict upload's behavior and mislead anyone sizing an SQS queue
for the upload topic.

## What Changes

- Edit the comment at line 59 of `src/groundx/values/values.aws.services.yaml` so it states that
  upload holds in-flight messages for 5 minutes (the upload consumer's lease, set in cashbot-go
  under GX-63), while the other SQS queues keep the 10+ minute requirement.
- Apply the identical edit to the manual mirror `helm/values/values.aws.services.yaml` (same
  line), editing `src/` first and then syncing `helm/`.
- No value, key, template, or default changes. Comment text only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `values-contract-semantics`: adds one requirement recording the documentation contract of the AWS example values (upload holds in-flight messages for 5 min, the other SQS queues keep 10+ min, src and helm identical). No runtime requirement changes; the requirement exists to give this documentation-only change a spec home.

## Impact

- **Blast radius:** none at runtime. A YAML comment is discarded by the parser, so rendered
  manifests are expected to be identical and no cluster, environment (dev/staging/prod), or
  stateful resource redeploys. To be confirmed at apply by comparing `helm template` output
  before and after the edit; `validate-helm.sh` still runs on push.
- **Affected files:** `src/groundx/values/values.aws.services.yaml` and
  `helm/values/values.aws.services.yaml` (the two are a manual mirror with no regen guard, so
  both are edited by hand and kept identical).
- **Cross-service:** the 5 minute upload lease itself is implemented in cashbot-go under GX-63;
  this change only documents it. On-prem upload defaults to Kafka, which has no lease, so
  on-prem installs are unaffected by the lease change.
- **Rollback / roll-forward:** revert the commit; there is nothing to migrate or redeploy.
- **Open design questions:** none.
