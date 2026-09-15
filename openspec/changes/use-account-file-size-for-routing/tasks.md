## Implementation

- [x] Remove counting.helperPath from both schemas and existing fixtures; require the helper beside the producer executable, regenerate existing snapshots, and pass the Helm gate.
- [x] Remove the schema property and fixture values; mirror the schema.
- [x] Regenerate existing snapshots and verify only intended config and hash changes.
- [x] Pass the full Helm gate and Cashbot chart compatibility tests.
- [x] Document compatible-image ordering and rollback; validate OpenSpec.
