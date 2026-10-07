## Context

Cashbot removes LargeFileRouting.MaxPDFBytes from deployment YAML and obtains the limit from effective account maxFileSize. Existing positive saved budgets remain readable; zero account limits use a positive unlimited sentinel.

## Decisions

Remove the schema property and requirement rather than leaving an ignored public option. Existing counting values already flow directly into Go configuration. Remove the property from the existing large-file and shared-Google fixtures and regenerate their owning resource snapshots. Mirror the schema change to helm. No new workloads, credentials or extraction behavior change.

## Rollout

Remove counting.helperPath from the schema and fixtures as well. Compatible producers locate large-file-pdf-count beside their executable, not relative to the working directory. The standard image already packages both in /app; no build layout changes are required.

Use compatible Cashbot QueueTrainFile images when applying this chart change. Remove the old fields from operator values. Older producers still require the fields, so restore them and the prior chart before reverting a producer. Disabled installations retain their manifests. No live Kubernetes rollout is included.

## Validation

Run the existing full Helm gate, inspect snapshot changes for unrelated churn, and run Cashbot's chart configuration test against this chart for both Kafka and SQS. Account defaults, override precedence, unlimited values and saved retries are tested by Cashbot.
