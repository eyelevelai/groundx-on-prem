## Ingress admission

Enabled file access rejects native `file.ingress` on the public delivery hostname or an enabled chart gateway ingress hostname. Hostnames use the ingress renderer's `tpl` expansion and case-insensitive comparison. Public-host collisions are rejected when gateway ingress is managed externally. Distinct native signing/store routes retain their paths, backend and TLS. Disabled unused gateway hostnames remain available to native storage ingress and storage/signing endpoints.

## Storage credential scope

The feature storage Secret reaches Go storage clients, the schema-migration hook, layout and extraction workloads. Ranker API/inference, summary API/inference, workspace and metrics receive no implicit feature credential. Operator global and per-service Secret imports remain intact, duplicate imports occur once and native S3 supports an empty feature Secret with ambient credentials. Gateway and upload credential imports do not depend on storage wait containers. Source templates and published mirror contain identical changes.

## Validation

The focused Helm suite passes 39 cases. The full `.build/bin/validate-helm.sh` gate passes 463 tests and 850 unchanged snapshots with the pinned v1.1.2 test-plugin binary, including source/mirror ingress admission, storage contracts, template mirrors, upgrade hooks and workspace checks. Source and mirror minikube renders pass. Disabled default and minikube manifests are byte-identical to the pushed `228af7ba9dcf20a00322ebeec73ce4ee0fa22f91` baseline on both chart surfaces.

Both surfaces retain Go, migration, layout and extraction credential consumers, reject effective public ingress collisions, preserve separate native TLS routes with MinIO and S3, allow disabled unused gateway aliases and support ambient S3 credentials. The large-file delivery workload retains its storage Secret. OpenSpec validation and `git diff --check` pass.

## Native storage ingress ports

Generated native ingress backends use `groundx.file.nativePort`, preserving the storage Service port independently of the private HTTPS origin. The `groundx.file.port` private-endpoint branch, worker waits, extraction settings, signing endpoints and credential imports retain their existing behavior. The source helper and ingress templates match the published mirror exactly.

Three new regressions failed before implementation because the native Service backend rendered 9443 or 443 instead of 9000, including the legacy Ingress API shape. All 39 focused cases pass after implementation. Disabled file access, external storage and custom-path controls pass. The full gate checks generated native backends and TLS on both chart surfaces with private HTTPS ports 443 and 9443 and an unused disabled gateway hostname.

Parsed source/mirror manifests compared with pushed baseline `87c61316accba58f2a4f9e5724b25d431c20f5e7` change only the native ingress backend in enabled cases. Disabled and external-storage disabled cases remain identical. With every extraction component enabled, all ten Go, layout and extraction storage waits retain the private endpoint host and port. These are local render checks; native signed HTTP reads and live ingress controller behavior remain unverified.

## Activation gates

Arcadia legacy, Arcadia v1, generic v1 and ADP v1 workflow definitions, runtime, prompt policy, task chains, schema routing and immutable outputs are unchanged. Their extraction credential imports are retained. No protected extraction fixture or live transport suite ran for these chart admission and unused-credential changes. Exact-version backend integration, compatible SDK/image adoption, protected transport and customer acceptance remain the release gates in tasks.md. No image publication, cluster mutation or deployment is included.
