## Ingress admission

Enabled file access rejects native `file.ingress` on the public delivery hostname or an enabled chart gateway ingress hostname. Hostnames use the ingress renderer's `tpl` expansion and case-insensitive comparison. Public-host collisions are rejected when gateway ingress is managed externally. Distinct native signing/store routes retain their paths, backend and TLS. Disabled unused gateway hostnames remain available to native storage ingress and storage/signing endpoints.

## Storage credential scope

The feature storage Secret reaches Go storage clients, the schema-migration hook, layout and extraction workloads. Ranker API/inference, summary API/inference, workspace and metrics receive no implicit feature credential. Operator global and per-service Secret imports remain intact, duplicate imports occur once and native S3 supports an empty feature Secret with ambient credentials. Gateway and upload credential imports do not depend on storage wait containers. Source templates and published mirror contain identical changes.

## Validation

The focused file-access and file-settings suites pass 60 cases, including 44 file-access cases. The full `.build/bin/validate-helm.sh` gate passes 468 tests and 850 unchanged snapshots with the pinned v1.1.2 test-plugin binary, including source/mirror ingress admission, storage contracts, template mirrors, upgrade hooks and workspace checks. Source and mirror minikube renders pass. Disabled default and minikube manifests are byte-identical to the pushed `228af7ba9dcf20a00322ebeec73ce4ee0fa22f91` baseline on both chart surfaces.

Both surfaces retain Go, migration, layout and extraction credential consumers, reject effective public ingress collisions, preserve separate native TLS routes with MinIO and S3, allow disabled unused gateway aliases and support ambient S3 credentials. The large-file delivery workload retains its storage Secret. OpenSpec validation and `git diff --check` pass.

## Native storage ingress ports

Generated native ingress backends use `groundx.file.nativePort`, preserving the storage Service port independently of the private HTTPS origin. The `groundx.file.port` private-endpoint branch, worker waits, extraction settings, signing endpoints and credential imports retain their existing behavior. The source helper and ingress templates match the published mirror exactly.

Three regressions failed before implementation because the native Service backend rendered 9443 or 443 instead of 9000, including the legacy Ingress API shape. All 44 focused file-access cases pass. Disabled file access, external storage and custom-path controls pass. The full gate checks generated native backends and TLS on both chart surfaces with private HTTPS ports 443 and 9443 and an unused disabled gateway hostname.

Parsed source/mirror manifests compared with pushed baseline `87c61316accba58f2a4f9e5724b25d431c20f5e7` change only the native ingress backend in enabled cases. Disabled and external-storage disabled cases remain identical. With every extraction component enabled, all ten Go, layout and extraction storage waits retain the private endpoint host and port. These are local render checks; native signed reads through a deployed ingress controller remain unverified.

## Extraction bucket admission

Enabled extraction and file access require the same effective bucket. Inherited and explicitly matching extraction buckets remain valid. The source helper and published mirror reject a separate bucket before deployment, while disabled file access and disabled extraction retain their existing behavior. No storage client, object migration, credential, stored URL or runtime state changes are introduced.

The regression test fails against the committed `fb8af682b9a52897d250747dc5fce4108a9e9a9e` helper with the pinned v1.1.2 plugin. Five cases cover rejection, inherited and explicit matching buckets, disabled file access and disabled extraction. The full gate also checks rejection on both chart surfaces. Twelve valid source/mirror render profiles are byte-identical to that baseline: default, minikube, enabled inherited/matching buckets, disabled separate buckets and unused extraction overrides.

A disposable local MinIO `RELEASE.2024-09-09T16-59-28Z` reproduction used production-rendered configuration, SDK bucket provisioning/upload and Cashbot resolver, gateway, storage and API functions. Separate-bucket output was anonymously readable with file access disabled. Matching private buckets returned 200 through the gateway, extraction API and native file-link, while unsigned origin reads returned 403. Separate private buckets returned gateway 404 and extraction API/file-link errors; main-bucket source delivery remained 200. Both chart surfaces produced these results. The local HTTP peer substituted only the network endpoint and test credentials; this does not certify HTTPS, deployed images or any backend release.

## Inline credential admission

At pushed baseline `0f59af5358d5ff381a37bc49460dfecd1cb2e60d`, enabled Go upload configuration omits `file.username`, `file.password` and `file.token`; layout clears its access key and secret, and extraction clears inherited or overridden username/password. The enabled-only validator rejects these nonempty ignored inputs, including when a feature Secret is also supplied, with a field-specific migration message that omits the value. Disabled file access, unused disabled-extraction overrides, enabled Secret configuration and native S3 ambient credentials retain their existing behavior. Source and published helper bytes match.

Six admission cases fail against the pushed helper and pass with the guard. All 69 focused cases pass. The full `.build/bin/validate-helm.sh` gate passes 477 tests and 850 unchanged snapshots using isolated Helm 3.19.0 and SHA-256-verified v1.1.2 plugin binaries, including both-surface rejection for all five fields. Fourteen admitted source/mirror profiles are byte-identical to the pushed baseline: default, minikube, enabled Secret, enabled extraction, ambient S3, disabled inline credentials and unused extraction credentials. OpenSpec strict validation, whitespace and LF checks pass. The three disabled inline controls cover Go, layout and extraction configuration; existing private endpoint assertions remain intact.

## Activation gates

Arcadia legacy, Arcadia v1, generic v1 and ADP v1 workflow definitions, runtime, prompt policy, task chains, schema routing and immutable outputs are unchanged. Their extraction credential imports and admitted deployment output are retained. No protected customer extraction fixture or deployed HTTPS transport suite ran for these chart admission and unused-credential changes. Exact-version backend integration, compatible SDK/image adoption, protected transport and customer acceptance remain the release gates in tasks.md. No image publication, cluster mutation or deployment is included.

## Inline credential validation closeout

Change `protect-hosted-file-access`, closed 2026-10-17T18:19:19.484601+00:00. Cleanup removed the exact `openspec/work/protect-hosted-file-access/inline-credential-admission-20261017` root (715 files, 218054244 bytes); absence is verified. The bounded lifecycle summary is `openspec/runs/protect-hosted-file-access/inline-credential-admission-20261017.json`, SHA-256 `2fb582db89fd88b1725e67691ded84c2473bc40bf838d5123fc8d8c3cd00fb5c`. Validation results remain in this file. No local validation root remains open.
