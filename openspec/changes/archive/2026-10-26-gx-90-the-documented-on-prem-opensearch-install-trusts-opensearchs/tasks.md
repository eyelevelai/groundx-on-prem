## 1. Thin slice: the chart takes a search CA, fails closed without it, mounts it and renders caFile (withdrawn 2026-10-29)

The suite `src/groundx/tests/search_ca_test.yaml` is the acceptance stub for this group; it was written first and fails on the unchanged chart because `search.caSecretName` is rejected by `values.schema.json`.

- [x] 1.1 Add `search.caSecretName` (string, default `""`) to `src/groundx/values.yaml` and `src/groundx/values.schema.json`; add `groundx.search.caSecretName` (fails when `groundx.search.create` is true and the value is empty, naming `search.caSecretName`), `groundx.search.caMount` and `groundx.search.caVolume` to `templates/_helpers/services/search.tpl`; call the guard from `templates/resources/config-yaml.yaml` beside the GX-75 password checks; render `caFile: /var/run/groundx/search-ca/ca.crt` under `ai.aws.search` when set; include the mount and volume in `templates/app/golang.yaml`
  check: n/a — withdrawn 2026-10-29: GX-90 uses the GX-130 `fileAccess.caSecretName` bundle, so the OpenSearch-only CA was removed

## 2. Existing render gates keep passing (withdrawn 2026-10-29)

- [x] 2.1 Add `caSecretName: fixture-search-ca` to `src/groundx/tests/files/values.search-credentials.yaml` and to the `search:` block of every suite under `src/groundx/tests/` that sets `privilegedPassword`; hand-patch only the snapshots that show the new `search-ca` volume, mount or `caFile` (never `helm unittest -u`), then verify without `-u`
  check: n/a — withdrawn 2026-10-29: GX-90 uses the GX-130 `fileAccess.caSecretName` bundle, so the OpenSearch-only CA was removed

## 3. Mirror the chart changes into helm/ (withdrawn 2026-10-29)

- [x] 3.1 Mirror `values.yaml`, `values.schema.json` and the changed templates (`_helpers/services/search.tpl`, `resources/config-yaml.yaml`, `app/golang.yaml`) by hand into `helm/`
  check: n/a — withdrawn 2026-10-29: GX-90 uses the GX-130 `fileAccess.caSecretName` bundle, so the OpenSearch-only CA was removed

## 4. OpenSearch install seed values

- [x] 4.1 Rewrite `src/groundx/values/opensearch/values.yaml` per design.md (override `config."opensearch.yml"` with operator-certificate paths under `certs/`, `admin_dn: CN=gx-opensearch-admin`, `nodes_dn: CN=opensearch-node`, `allow_default_init_securityindex: true`, `restapi.roles_enabled`, upstream `system_indices`; `extraEnvs` `DISABLE_INSTALL_DEMO_CONFIG=true`; `secretMounts` for `opensearch-tls` at `/usr/share/opensearch/config/certs`; `securityConfig.internalUsersSecret: opensearch-internal-users`) and copy it byte-identical to `helm/values/opensearch/values.yaml`; no certificate, key or hash material
  check: bash src/groundx/tests/files/verify-opensearch-tls-values.sh
- [x] 4.2 Wire `verify-opensearch-tls-values.sh` into `.build/bin/validate-helm.sh` after the probe-mirror check
  check: grep -q 'bash src/groundx/tests/files/verify-opensearch-tls-values.sh' .build/bin/validate-helm.sh

## 5. Documentation

- [x] 5.1 Update `README.md` `### OpenSearch` and `#### Upgrading an Existing Install` per the spec: demo-TLS caveat, operator inputs (CA, node cert SAN and subject, admin cert subject, bcrypt hash generated with the image's `hash.sh`, no values committed), `opensearch-tls` and `opensearch-internal-users` Secrets created before OpenSearch starts, `helm install ... --version 2.23.1` without `opensearch-admin.values.yaml` or `OPENSEARCH_INITIAL_ADMIN_PASSWORD`, the `fileAccess.caSecretName` bundle and the image note, restart-based rotation (OpenSearch, then `groundx`, then `process`), upgrade step 3 on the operator admin certificate (copied into the pod for the command and removed afterwards) with removal of the six demo users from the backed-up `internal_users.yml`, and upgrade steps that add the CA to the `fileAccess.caSecretName` bundle, set the credentials and remove the demo users before a final step that upgrades and restarts `groundx` and `process`; keep exactly one README line matching each mirrored install-block marker used by the harness scan (Revised 2026-10-29: rotation separates a same-CA renewal from a CA change; see the design Amendments.)
  check: ! grep -q 'kirk' README.md && ! grep -q 'OPENSEARCH_INITIAL_ADMIN_PASSWORD' README.md && ! grep -q -- '-----BEGIN' README.md && grep -q 'fileAccess.caSecretName' README.md && ! grep -q 'search.caSecretName' README.md && grep -q 'opensearch-tls' README.md && grep -q 'opensearch-internal-users' README.md && grep -q 'CN=gx-opensearch-admin' README.md
- [x] 5.2 Move the `search-credential-required` README requirement to the modified text (spec delta in this change)
  check: n/a — OpenSpec delta, applied by archive

## 6. Human-run live-cluster checks (the pipeline executes none of these)

- [x] 6.1 AC1/G1 on a throwaway cluster, README steps followed with locally issued test certificates: (a) OpenSearch starts and `_cluster/health` is green over HTTPS with the operator CA; (b) a request authenticated with the published demo admin certificate is rejected, and one with the operator admin certificate (`CN=gx-opensearch-admin`) and `securityadmin.sh` works; (c) the admin password `admin` and the demo users are rejected; (d) `kubectl exec ... cat config/opensearch.yml` shows no `allow_unsafe_democertificates` or `CN=kirk`; (e) `openssl s_client -verify_hostname opensearch-cluster-master.<ns>.svc.cluster.local -CAfile ca.crt` chains (Result 2026-10-29, local minikube profile `gx90`, chart at 25a01634, image `latest@sha256:8e95a30f…`, README steps with locally issued test certificates: (a) `_cluster/health` green over HTTPS with the operator CA; (b) the published demo admin certificate (`CN=kirk`) is refused in the TLS handshake for the REST API and by `securityadmin.sh`, while the operator admin certificate returns 200 and `securityadmin.sh -backup` exits 0; (c) `admin:admin` and the demo users `kibanaro`, `readall`, `logstash`, `snapshotrestore` return 401 and `admin` is the only stored user; (d) the running `opensearch.yml` has no `allow_unsafe_democertificates` and no `CN=kirk`, `admin_dn` is `CN=gx-opensearch-admin`, `nodes_dn` is `CN=opensearch-node`, `DISABLE_INSTALL_DEMO_CONFIG=true` and no demo certificate files exist; (e) `openssl s_client -verify_hostname opensearch-cluster-master.eyelevel.svc.cluster.local -CAfile ca.crt` returns `Verify return code: 0` with subject `CN=opensearch-node`, while connecting by pod IP or trusting the demo root CA fails verification.)
  check: n/a — human-run live-cluster check before merge
- [x] 6.2 G1 end to end: use `groundx` and `process` images with certificate verification (cashbot-go #1865) and the OpenSearch CA in the `fileAccess.caSecretName` bundle, then ingest a document and run a search; also confirm a pod whose bundle lacks the OpenSearch CA refuses to connect (Revised 2026-10-29: scoped to this ticket, OpenSearch certificates and GroundX trust in them; ingest through layout and summary needs the GPU inference services and is outside GX-90. Result, local minikube profile `gx90`: a probe built from cashbot-go master 6752c7d67 calls `httpclient.InitCrawlClient`, the transport `groundx` and `process` use for OpenSearch, with the `groundx-ca-bundle` Secret mounted at `/var/run/groundx/file-access/ca.crt` and `SSL_CERT_FILE` set as the chart renders it for `groundx` and `process`; it created an index, wrote a document, found it by search and deleted the index. With a public-roots-only bundle, and with no bundle, the same probe failed with `x509: certificate signed by unknown authority`. Upgrade path on a second namespace installed as released 0.2.8 documents it (demo security configuration, `admin:admin`, the demo certificate accepted as admin): after README step 1 the demo certificate is refused and every stored user is kept; after step 6 only `admin`, the application user `eyelevel` and a customer-created user remain, the rotated admin password works, `admin:admin` and all six demo users return 401, and this holds after a restart.)
  check: n/a — human-run live-cluster check before merge

## 7. Gate

- [ ] 7.1 Run `.build/bin/validate-helm.sh` from the git pre-push gate with helm v3.19.0; on a snapshot difference hand-patch, verify without `-u`, then run `verify-helm-snapshots.py`
  check: n/a — verification run of the CI gate in the verify phase; the behavior it guards is checked by task 4.1

See workspace `openspec/changes/` for cross-service coordination (the studio-harness docs and deferred items; the cashbot-go change was withdrawn because GX-130 already verifies the OpenSearch certificate).
