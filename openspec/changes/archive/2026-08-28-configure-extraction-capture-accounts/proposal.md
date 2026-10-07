# Configure extraction capture accounts

Cashbot already rejects `_groundx_internal_capture` unless the caller account is
in `integrationTests.extractionCaptureAccounts`. The Helm chart cannot render
that setting, so governed extraction certification is denied in every Helm
deployment.

Add an optional `integration.extractionCaptureAccounts` values list and render
it into `config.yaml`. The default remains empty, so no account gains capture
access unless an operator explicitly configures it.

The deployment contract, generated GroundX ConfigMap, and workloads whose
config hash includes that ConfigMap are affected. A rollout may restart enabled
Go services and the metrics service. Databases, queues, files, customer data,
workflow compilation, and extraction behavior are unchanged.

Production rollout sets the approved internal testing account, waits for all
affected Helm workloads to become ready with zero new restarts, and verifies the
rendered allowlist. This chart does not deploy the hosted GroundX Lambda. Hosted
API certification also requires the Cashbot-owned production config and Lambda
release path. Rollback removes the value and repeats the owning deployment. No
data migration is required.

Open design questions: none.
