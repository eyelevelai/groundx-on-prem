## Why

Deploy the merged AGE-344 credential-cleanup fix. Scope is existing managed app
uninstall workflows and the six Workspace runner images in eyelevel_890ng3,
account 903713046261, us-west-2. Test only a disposable app in groundx-studio-dev.

## What Changes

- Update default and active branches of existing managed repositories to support
  purge-only runtime Secret deletion, preserving project-specific deployment targets.
- Build runner 8a6e9b4 and replace only the six Workspace images after any concurrent
  Helm operation completes. Retain the exact deployed chart and all other values.
- Verify teardown preserves the disposable app's Secret and permanent purge removes
  it and its owned resources. Remove test artifacts afterward.

## Capabilities

### New Capabilities
- `runtime-credential-cleanup-rollout`: Safely deploy and verify purge cleanup.

### Modified Capabilities
None.

## Impact

Existing apps are not republished or deleted. No new shared infrastructure, production
managed-data enablement, schema migration, or customer data changes. Existing development
services cover testing, with only temporary build/storage costs. Rollback restores only
the prior runner image; additive workflow support can remain. Open questions: none.
