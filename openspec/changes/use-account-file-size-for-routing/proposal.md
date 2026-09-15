## Why

The delivery chart requires a second PDF byte limit even though account maxFileSize already controls permitted uploads. A smaller deployment cap rejects accepted PDFs before page routing.

## What Changes

- Remove largeFileDeliver.counting.maxPDFBytes from the values schema and existing fixtures.
- Require the compatible Cashbot producer that snapshots effective account maxFileSize for counting and delivery.
- Regenerate existing resource snapshots and mirror the source schema to helm.

## Capabilities

### New Capabilities

- `account-file-size-routing`: Account-owned byte limits without a chart override.

## Impact

Only enabled large-file delivery configuration changes. Existing saved runs and credentials remain unchanged. No cluster deployment, data migration or production change is included. Upgrade producer images with this configuration; rollback requires restoring the old chart setting before using an old producer. Open design questions: none.
