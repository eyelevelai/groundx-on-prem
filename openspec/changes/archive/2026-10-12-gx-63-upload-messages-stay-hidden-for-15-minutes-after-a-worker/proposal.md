## Why

`src/groundx/values/values.aws.services.yaml` tells operators that the queue visibility timeout
"must be 10+ min for all SQS queues". GX-63 makes the upload, process and summary consumers hold
in-flight messages for 5 minutes (renewed every minute) so a crashed worker's messages become
visible again sooner. The note would then contradict those consumers' behavior and mislead anyone
sizing an SQS queue for them.

## What Changes

- Edit the comment at line 59 of `src/groundx/values/values.aws.services.yaml` so it states that
  the upload, process and summary consumers re-hide in-flight messages for 5 minutes, renewed every minute, and a DLQ on the upload queue needs maxReceiveCount of 4 or more (the lease is set in cashbot-go
  under GX-63), while the other SQS queues keep the 10+ minute requirement.
- Apply the identical edit to the manual mirror `helm/values/values.aws.services.yaml` (same
  line), editing `src/` first and then syncing `helm/`.
- No value, key, template, or default changes. Comment text only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `values-contract-semantics`: adds one requirement recording the documentation contract of the AWS example values (the upload, process and summary consumers re-hide in-flight messages for 5 min renewed every minute, a DLQ on upload needs maxReceiveCount 4+, SQS queues keep 10+ min, src and helm identical). No runtime requirement changes; the requirement exists to give this documentation-only change a spec home.

## Impact

- **Blast radius:** none at runtime. A YAML comment is discarded by the parser, so rendered
  manifests are expected to be identical and no cluster, environment (dev/staging/prod), or
  stateful resource redeploys. To be confirmed at apply by comparing `helm template` output
  before and after the edit; `validate-helm.sh` still runs on push.
- **Affected files:** `src/groundx/values/values.aws.services.yaml` and
  `helm/values/values.aws.services.yaml` (the two are a manual mirror with no regen guard, so
  both are edited by hand and kept identical).
- **Cross-service:** the 5 minute lease itself is implemented in cashbot-go under GX-63;
  this change only documents it. A queue on Kafka has no lease (the Kafka client has no
  visibility call), so on-prem installs that keep Kafka for a queue are unaffected by the lease change for it.
- **Rollback / roll-forward:** revert the commit; there is nothing to migrate or redeploy.
- **Open design questions:** none.
