## Context

Cashbot removes LargeFileRouting.MaxPDFBytes from deployment YAML and obtains the limit from effective account maxFileSize. Existing positive saved budgets remain readable; zero account limits use a positive unlimited sentinel.

## Decisions

Remove the schema property and requirement rather than leaving an ignored public option. Existing counting values already flow directly into Go configuration. Remove the property from the existing large-file and shared-Google fixtures and regenerate their owning resource snapshots. Mirror the schema change to helm. No new workloads, credentials or extraction behavior change.

## Rollout

Use compatible Cashbot QueueTrainFile images when applying this chart change. Remove the old field from operator values. Older producers still require the field, so restore it and the prior chart before reverting a producer. Disabled installations retain their manifests. No live Kubernetes rollout is included.

## Validation

Run the existing full Helm gate, inspect snapshot changes for unrelated churn, and run Cashbot's chart configuration test against this chart for both Kafka and SQS. Account defaults, override precedence, unlimited values and saved retries are tested by Cashbot.
