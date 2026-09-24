# Configure extraction capture domains

The chart currently exposes only exact account IDs for extraction capture. Cashbot will also accept internal account email domains from `integrationTests.extractionCaptureDomains`. Expose those domains as `integration.extractionCaptureDomains` and render them into the shared `config.yaml` without changing the capture marker or extraction behavior.

The source chart and published `helm/` mirror change together. A config hash may restart enabled Go API services and metrics during rollout. No database or persistent-data changes occur. Rollback removes the value and reapplies the chart. The hosted Lambda uses a separate Cashbot production config and release path.

The default remains empty. Operators must explicitly enable domains for an installation.
Open design questions: none.
