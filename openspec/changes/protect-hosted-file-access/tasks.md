## 1. Local deployment

- [x] 1.1 Specify endpoint separation, optional values, upstream config fields, store matrix, S4 constraints and release/rollback gates.
- [x] 1.2 Add values/schema/helpers and gateway Deployment/Service/probes/ingress. Extend existing file-settings tests to prove disabled compatibility, endpoint-loop and missing-readiness rejection, HTTPS presentation and single bucket paths. Generated ingress preserves Host/path/query; actual request behavior remains gated by 1.5.
- [ ] 1.3 Render compatible Cashbot and ai-server configuration together, including uploadStorageEndpoint and uploadPublicRead=false when enabled. Configuration, extraction SDK fields and credential/trust references are covered by chart tests. Exact API/gateway/worker image adoption and migration-hook runtime compatibility remain unverified release gates.
- [x] 1.4 Sync changed source files to helm; run .build/bin/validate-helm.sh and explicit source/mirror renders, never regenerate unrelated snapshots. The full gate passes with 434 tests and 850 unchanged snapshots; disabled default/minikube/cloud/extract profiles are byte-identical on both surfaces.
- [ ] 1.5 Pin exact MinIO/AIStor versions/digests and the specified S4 chart/image digest. Run the identical public/authenticated/wrong-owner/share/expiry/PUT/range/HEAD/conditional/TLS/encryption and large X-Ray view=links suite on every advertised store. Preserve that query and keep transformed views fresh/no-store.
- [ ] 1.6 Verify private worker ingest, extraction, copy and callback transport; run Arcadia legacy, Arcadia v1, generic v1 and ADP v1 when transport is touched. Retain exact output bytes and answer keys.
- [ ] 1.7 Load-test cold mappings, hot scopes and concurrent large downloads, record hardware/store limits and Redis headroom, and enforce the documented availability envelope including S4's single replica.
- [ ] 1.8 Publish operator setup and migration/rollback guidance only after observed integration evidence. No deployment is performed as part of planning.

## 2. Independent backend releases

- [ ] 2.1 Publish/review the plan and coordinate shared contracts. Release local support for a backend only after its pinned integration/workload passes; incomplete AIStor/S4 runs do not block cloud ADP or independently verified MinIO support.
- [ ] 2.2 Record every advertised backend version/digest and remaining unverified backend in release/closeout. Unfinished commitments remain in this change or a referenced successor; no universal compatibility claim.

## Branch continuity

- [ ] Keep planning and implementation on the existing plan/protect-hosted-file-access working branch and the same draft PR in this repository. Append code/tests to that PR after design review; mark it ready after implementation and required gates, without a separate planning merge.
