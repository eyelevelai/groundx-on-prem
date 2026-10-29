## 1. Local deployment

- [x] 1.1 Specify endpoint separation, optional values, upstream config fields, store matrix, S4 constraints and release/rollback gates.
- [x] 1.2 Add values/schema/helpers and gateway Deployment/Service/probes/ingress. Extend existing file-settings tests to prove disabled compatibility, endpoint-loop and missing-readiness rejection, HTTPS presentation and single bucket paths. Generated ingress preserves Host/path/query; actual request behavior remains gated by 1.5.
- [ ] 1.3 Render compatible Cashbot and ai-server configuration together, including uploadStorageEndpoint and uploadPublicRead=false when enabled. Configuration, extraction SDK fields and credential/trust references are covered by chart tests. Exact API/gateway/worker image adoption and migration-hook runtime compatibility remain unverified release gates.
- [x] 1.4 Sync changed source files to helm; run .build/bin/validate-helm.sh and explicit source/mirror renders, never regenerate unrelated snapshots. The full gate passes with 463 tests and 850 unchanged snapshots; disabled default/minikube/cloud/extract profiles are byte-identical on both surfaces.
- [ ] 1.5 Pin exact MinIO/AIStor versions/digests and the specified S4 chart/image digest. Run the identical public/authenticated/wrong-owner/share/expiry/PUT/range/HEAD/conditional/TLS/encryption and large X-Ray view=links suite on every advertised store. Preserve that query and keep transformed views fresh/no-store.
- [ ] 1.6 Verify private worker ingest, extraction, copy and callback transport; run Arcadia legacy, Arcadia v1, generic v1 and ADP v1 when transport is touched. Retain exact output bytes and answer keys.
- [ ] 1.7 Load-test cold mappings, hot scopes and concurrent large downloads, record hardware/store limits and Redis headroom, and enforce the documented availability envelope including S4's single replica.
- [ ] 1.8 Publish operator setup and migration/rollback guidance only after observed integration evidence. No deployment is performed as part of planning.

## 2. Independent backend releases

- [ ] 2.1 Publish/review the plan and coordinate shared contracts. Release local support for a backend only after its pinned integration/workload passes; incomplete AIStor/S4 runs do not block cloud ADP or independently verified MinIO support.
- [ ] 2.2 Record every advertised backend version/digest and remaining unverified backend in release/closeout. Unfinished commitments remain in this change or a referenced successor; no universal compatibility claim.

## Branch continuity

- [ ] Keep planning and implementation on the existing plan/protect-hosted-file-access working branch and the same draft PR in this repository. Append code/tests to that PR after design review; mark it ready after implementation and required gates, without a separate planning merge.

## 3. Ingress and credential admission

- [x] 3.1 Reject effective legacy native ingress collisions with the public host and enabled chart gateway hosts for managed and external gateway ingress; preserve distinct native signing/store routes and disabled behavior.
- [x] 3.2 Scope feature storage credentials to verified Go, migration, layout and extraction consumers; preserve explicit global/per-service Secret imports and ambient S3 behavior.
- [x] 3.3 Prove the new Helm regressions fail before implementation and pass afterward; mirror exact template bytes, run the full chart gate and source/mirror minikube renders.

## 4. Native ingress port separation

- [x] 4.1 Add generated native ingress regressions for Service port 9000 with private HTTPS origins on 443 and 9443, legacy Ingress API rendering and disabled unused gateway hostnames. Prove the port assertions fail before the fix; retain disabled, external storage and explicit custom-path controls.
- [x] 4.2 Factor native port resolution into `groundx.file.nativePort` and select it only for the native file ingress. Preserve storage waits, extraction settings and client configuration; mirror both templates.
- [x] 4.3 Run focused tests, both chart render surfaces, the full pinned Helm gate, minikube renders, OpenSpec validation and whitespace/line-ending checks. Keep live transport and backend compatibility gates open.

## 5. Extraction bucket admission

- [x] 5.1 Reproduce the separate-bucket failure with production-rendered configuration, SDK bucket provisioning/upload and Cashbot gateway, extraction API and native-link paths. Retain disabled separate-bucket and enabled matching-bucket positive controls.
- [x] 5.2 Add an enabled-only effective extraction bucket equality guard, mirror the helper and retain inherited, explicitly matching, disabled file-access and disabled extraction configurations. Add failing-first coverage to the existing file-access Helm suite and source/mirror admission checks.
- [x] 5.3 Run the focused Helm suites, full pinned chart gate, source/mirror minikube renders, OpenSpec and whitespace/line-ending checks. Retain independent backend activation and protected transport gates.

## 6. Inline credential admission

- [x] 6.1 Extend existing Helm and source/mirror render checks to reject each ignored inline file credential and enabled-extraction override. Prove rejection cases fail before implementation; retain feature-off inline, unused disabled-extraction, Secret and ambient S3 controls.
- [x] 6.2 Reject nonempty ignored fields in the existing enabled file-access validator with a safe migration message. Mirror the helper and document the credential migration.
- [x] 6.3 Run focused tests, full pinned Helm gate, source/mirror minikube renders, OpenSpec and whitespace checks without regenerating snapshots. Record local evidence and retain live backend and protected extraction activation gates.

## Unified upload signing

- [x] Use one authenticated bucket upload operation for public and protected uploads; preserve explicit legacy compatibility.
- [x] Update owning implementation and human/agent instructions without new CI scripts.
- [x] Extend existing storage/render/widget tests for protection disabled, local/non-AWS storage and failure without hosted fallback.
- [ ] Refresh generated mirrors and run existing validators; record deployment tests separately.

The source and published chart render public signing independently of protection,
preserve legacy inline credentials, and retain the protected signing endpoint's
precedence. File settings and gateway tests are consolidated in the existing
file_settings_test.yaml with every pre-existing test case unchanged. Both chart
lints, exact public/protected configuration renders, mirror equality, strict
OpenSpec and whitespace checks pass. Full validate-helm stops before tests because
the installed helm-unittest is 1.0.3 and the repository requires verified 1.1.2.
No live deployment or vendor certification was performed.

## Historical originals (GX-88)

- [x] Document bounded current-document and task-history binding passes before activation, compatible writers during cutover, ownership verification and rollback. Schema creation alone is insufficient. No chart, deployment or database change is included.

- [x] Replace the separate historical binding backfill requirement with the normal
  schema upgrade and first-access migration. Require older writers to stop while
  the one-time reference index is built, compatible writers before resume, and
  backend-specific owner/denial verification before activation. Backend PR #1866
  owns implementation and local evidence; this documentation does not certify a
  deployed store or authorize an upgrade.

## Storage alias release 0.2.9

- [x] Set source and mirrored chart `version` and `appVersion` to 0.2.9, preserving the published 0.2.8 release.
- [x] Run the existing full Helm gate and verify rendered default image tags are 0.2.9 in both chart trees. All 545 tests and 850 unchanged snapshots pass with the CI toolchain; dependency image versions are unchanged.
- [ ] Build compatible 0.2.9 application images and complete deferred on-prem qualification before publishing the new release. This PR does not publish charts, retag images or upgrade installations.

## Cloud implementation handoff

SDK 4.1.6 is released. Cashbot PRs #1886, #1889 and #1890, ai-server #86, extraction #215 and Harness #293 are merged with passing checks. Dev public/protected PDF, PNG and JPG extraction and file-link acceptance passed; registered ADP scored 99/102 public and 101/102 protected against the existing 95% threshold. AI-server changes are tests and guidance only.

The merged Go and extraction builds are deployed and verified in cloud production. Public/protected PDF, PNG and JPG extraction, document/search links, sharing-link expiry and policy precedence passed. The legacy X-Ray and all 84 embedded assets passed clean/tracked reads. Synthetic resources and temporary artifacts were removed. No SQL or infrastructure changes were needed.

Chart 0.2.9 image builds, publication and live on-prem qualification remain deferred. The cross-repository storage-alias plan stays open for that release handoff. Cloud verification does not certify an on-prem installation.

## Hosted download local artifact closeout

- Owner: `cashbot-go`
- Change: `verify-cloud-file-access`
- Run: `hosted-download-query-20261029`
- Closed: `2026-10-29T15:51:58.504406+00:00`
- Cleanup state: complete
- Removed files: 13
- Removed symlinks: 0
- Removed bytes: 69065962
- Run root absent: true
- External run roots: none
- Summary SHA-256: `9c83c3ad6d34870b2a7952fdb6faa6479f598c416dad017aa78a81b3077323e5`
