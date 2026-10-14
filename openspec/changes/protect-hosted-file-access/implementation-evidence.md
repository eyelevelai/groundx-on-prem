## Ingress admission

Enabled file access rejects native `file.ingress` on the public delivery hostname or an enabled chart gateway ingress hostname. Hostnames use the ingress renderer's `tpl` expansion and case-insensitive comparison. Public-host collisions are rejected when gateway ingress is managed externally. Distinct native signing/store routes retain their paths, backend and TLS. Disabled unused gateway hostnames remain available to native storage ingress and storage/signing endpoints.

## Storage credential scope

The feature storage Secret reaches Go storage clients, the schema-migration hook, layout and extraction workloads. Ranker API/inference, summary API/inference, workspace and metrics receive no implicit feature credential. Operator global and per-service Secret imports remain intact, duplicate imports occur once and native S3 supports an empty feature Secret with ambient credentials. Gateway and upload credential imports do not depend on storage wait containers. Source templates and published mirror contain identical changes.

## Validation

The focused Helm suite passes 34 cases. The full `.build/bin/validate-helm.sh` gate passes 458 tests and 850 unchanged snapshots with the pinned v1.1.2 test-plugin binary, including source/mirror ingress admission, storage contracts, template mirrors, upgrade hooks and workspace checks. Source and mirror minikube renders pass. Disabled default and minikube manifests are byte-identical to the pushed `228af7ba9dcf20a00322ebeec73ce4ee0fa22f91` baseline on both chart surfaces.

Both surfaces retain Go, migration, layout and extraction credential consumers, reject effective public ingress collisions, preserve separate native TLS routes with MinIO and S3, allow disabled unused gateway aliases and support ambient S3 credentials. The large-file delivery workload retains its storage Secret. OpenSpec validation and `git diff --check` pass.

## Activation gates

Arcadia legacy, Arcadia v1, generic v1 and ADP v1 workflow definitions, runtime, prompt policy, task chains, schema routing and immutable outputs are unchanged. Their extraction credential imports are retained. No protected extraction fixture or live transport suite ran for these chart admission and unused-credential changes. Exact-version backend integration, compatible SDK/image adoption, protected transport and customer acceptance remain the release gates in tasks.md. No image publication, cluster mutation or deployment is included.
