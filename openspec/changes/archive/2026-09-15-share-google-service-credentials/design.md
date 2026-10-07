# Design

Add `google.credentials` (chart-relative JSON path), or `google.existingSecret` with optional `google.secretKey` (default `credentials.json`). These sources are mutually exclusive. Empty `google` is disabled.

When Google OCR is enabled, an absent legacy `layout.ocr.credentials` can inherit the shared source. A legacy OCR path overrides the shared source. Large-file credential entries select the shared source with `sharedGoogle: true`, alternatively retaining the existing `secretName` and `secretKey` pair. Missing shared configuration is an error for an explicit delivery selection.

A named helper resolves shared Secret name/key and identifies consumers. A managed shared Secret is rendered only while at least one consumer uses it, independently of OCR enablement. The shared JSON is never placed in the common Go configuration or mounted into unrelated Go/extract/workspace pods. Existing layout credential file paths and Go delivery configuration paths remain unchanged.

Keep the old OCR resource and mounts unchanged for legacy settings. Shared OCR mounts use the same layout workload boundary and file path. Managed shared credential content hashes restart consuming layout and delivery pods when the file changes. Existing external Secrets are not read during rendering; document the explicit OCR restart needed for their subPath mount.

Tests extend the existing celery, golang and resources suites. Cover managed/shared-existing sources, either/both/neither consumers, per-service overrides, missing sources/files, ambiguous settings, rotation hashes and credential isolation. Preserve old snapshot entries. Render and compare both chart surfaces and decode delivery configuration using Cashbot's existing integration test. Arcadia legacy/v1, generic v1 and ADP v1 extraction contracts are unaffected: no extraction runtime, schema, dispatch or model behavior changes; shared credentials must not appear in extraction workloads.
