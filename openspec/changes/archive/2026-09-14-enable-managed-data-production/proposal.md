## Why

The deployed Workspace runner supports managed records, objects, and cache, but
production provider settings are empty. Production app allocation cannot complete.
Development allocation, persistence, isolation, ordinary teardown, republication,
and permanent deletion have passed live checks.

## What Changes

- Reuse the existing private production Aurora writer with an isolated managed-app
  administration account and app-specific databases. Do not change existing passwords.
- Add a private production S3 bucket and encrypted Redis cache with one standby.
- Extend only the dedicated Workspace role to production app resources.
- Configure production provider settings and verified database TLS for Workspace.
- Test one disposable private production app, then remove its owned resources.

## Impact

AWS account 903713046261, region us-west-2, cluster eyelevel_890ng3, existing
Workspace service. No new runner, application code, customer-app redeployment,
existing credential rotation, or existing data migration. Development records and
objects remain enabled.

Two cache.t4g.micro nodes cost USD 0.032/hour, or USD 23.36 per 730-hour month,
plus database usage, S3 storage/requests, and network traffic. This rate was read
from the AWS Pricing API on 2026-09-14. No reserved commitment is required.
This setup is approved. Remove the unused development cache, saving USD 11.68
per 730-hour month; the net cache increase is USD 11.68/month.

Rollback restores only the prior Workspace production settings and preserves
allocated data. Do not roll back unrelated Helm changes or remove shared services.
