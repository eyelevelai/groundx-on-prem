## Why

The current chart enumerates its Go workloads and stream topics. A cashbot-go image containing SummaryBillDeliver alone cannot deploy the worker or provision its topic. This change supplies the Kubernetes dependency of cashbot-go's `route-summary-bills-before-preprocess` change.

## What Changes

- Add an optional `summaryBillDeliver` Go workload, disabled by default, using the existing generic Go deployment template.
- Add the optional `file-summary-bill` stream topic and producer/consumer config, matching the implemented cashbot-go configuration contract.
- Extend values/schema, service helpers, required resource/credential bindings, and render tests. Edit `src/groundx/` first and mirror the shipping changes to `helm/`.
- Preserve the rendered default installation when this feature is disabled.

## Capabilities

### New Capabilities
- `summary-bill-deployment`: opt-in delivery worker and transport configuration.

### Modified Capabilities
None.

## Impact

Applies to opted-in Kubernetes installations in any environment. Enabling adds a CPU worker, stream topic/queue access, stored-file/database access, and outbound Google Drive access. Shared Go configuration changes can restart existing Go deployments through the config hash. No stateful store replacement or data migration is performed here. Disabled installations must retain existing resources and configuration.

Cashbot-go owns the additive routing column, routing/delivery semantics, binary packaging and callbacks. Cloud Lambda/SQS activation does not depend on this chart change. No deployment, credentials mutation, chart publication or customer activation is authorized by this plan.

Roll out compatible images and schema with account routing off; verify topic and worker readiness before enabling any account. Rollback disables new account claims while retaining the worker, credentials, topic and receipts until pending delivery/finalization is drained or reconciled. Removing the worker early would strand work.

Open design questions: none. The exact worker config bindings depend on the corresponding cashbot-go implementation; deployment budgets and secret references come from its measured activation record.
