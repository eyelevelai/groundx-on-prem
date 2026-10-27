## 1. Thin slice: the chart takes a search CA, fails closed without it, mounts it and renders caFile

The suite `src/groundx/tests/search_ca_test.yaml` is the acceptance stub for this group; it was written first and fails on the unchanged chart because `search.caSecretName` is rejected by `values.schema.json`.

- [x] 1.1 Add `search.caSecretName` (string, default `""`) to `src/groundx/values.yaml` and `src/groundx/values.schema.json`; add `groundx.search.caSecretName` (fails when `groundx.search.create` is true and the value is empty, naming `search.caSecretName`), `groundx.search.caMount` and `groundx.search.caVolume` to `templates/_helpers/services/search.tpl`; call the guard from `templates/resources/config-yaml.yaml` beside the GX-75 password checks; render `caFile: /var/run/groundx/search-ca/ca.crt` under `ai.aws.search` when set; include the mount and volume in `templates/app/golang.yaml`
  check: d="$(mktemp -d)" && cp -r src/groundx "$d/groundx" && (cd "$d/groundx" && helm unittest -f tests/search_ca_test.yaml .)

## 2. Existing render gates keep passing

- [x] 2.1 Add `caSecretName: fixture-search-ca` to `src/groundx/tests/files/values.search-credentials.yaml` and to the `search:` block of every suite under `src/groundx/tests/` that sets `privilegedPassword`; hand-patch only the snapshots that show the new `search-ca` volume, mount or `caFile` (never `helm unittest -u`), then verify without `-u`
  check: [ -z "$(grep -L caSecretName src/groundx/tests/files/values.search-credentials.yaml $(grep -l privilegedPassword src/groundx/tests/*_test.yaml))" ] && d="$(mktemp -d)" && cp -r src/groundx "$d/groundx" && mkdir -p "$d/groundx/files/ocr" && printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$d/groundx/files/ocr/gcv-test.json" && (cd "$d/groundx" && args=() && for f in $(grep -l privilegedPassword tests/*_test.yaml | grep -v celery_test); do args+=(-f "$f"); done && helm unittest "${args[@]}" .)

## 3. Mirror the chart changes into helm/

- [x] 3.1 Mirror `values.yaml`, `values.schema.json` and the changed templates (`_helpers/services/search.tpl`, `resources/config-yaml.yaml`, `app/golang.yaml`) by hand into `helm/`
  check: for f in values.yaml values.schema.json templates/_helpers/services/search.tpl templates/resources/config-yaml.yaml templates/app/golang.yaml; do cmp "src/groundx/$f" "helm/$f" || exit 1; done && helm template mirror helm --set search.password=fixture-app-credential --set search.privilegedPassword=fixture-admin-credential --set search.caSecretName=fixture-search-ca -s templates/resources/config-yaml.yaml | grep -q 'caFile: /var/run/groundx/search-ca/ca.crt'

## 4. OpenSearch install seed values

- [x] 4.1 Rewrite `src/groundx/values/opensearch/values.yaml` per design.md (override `config."opensearch.yml"` with operator-certificate paths under `certs/`, `admin_dn: CN=gx-opensearch-admin`, `nodes_dn: CN=opensearch-node`, `allow_default_init_securityindex: true`, `restapi.roles_enabled`, upstream `system_indices`; `extraEnvs` `DISABLE_INSTALL_DEMO_CONFIG=true`; `secretMounts` for `opensearch-tls` at `/usr/share/opensearch/config/certs`; `securityConfig.internalUsersSecret: opensearch-internal-users`) and copy it byte-identical to `helm/values/opensearch/values.yaml`; no certificate, key or hash material
  check: bash src/groundx/tests/files/verify-opensearch-tls-values.sh
- [x] 4.2 Wire `verify-opensearch-tls-values.sh` into `.build/bin/validate-helm.sh` after the probe-mirror check
  check: grep -q 'bash src/groundx/tests/files/verify-opensearch-tls-values.sh' .build/bin/validate-helm.sh

## 5. Documentation

- [x] 5.1 Update `README.md` `### OpenSearch` and `#### Upgrading an Existing Install` per the spec: demo-TLS caveat, operator inputs (CA, node cert SAN and subject, admin cert subject, bcrypt hash generated with the image's `hash.sh`, no values committed), `opensearch-tls` and `opensearch-internal-users` Secrets created before OpenSearch starts, `helm install ... --version 2.23.1` without `opensearch-admin.values.yaml` or `OPENSEARCH_INITIAL_ADMIN_PASSWORD`, `search.caSecretName` and the image note, restart-based rotation (OpenSearch, then `groundx`, then `process`), upgrade step 3 on the operator admin certificate (copied into the pod for the command and removed afterwards) with removal of the six demo users from the backed-up `internal_users.yml`, and upgrade steps that set `search.caSecretName` and the credentials and remove the demo users before a final step that upgrades and restarts `groundx` and `process`; keep exactly one README line matching each mirrored install-block marker used by the harness scan
  check: ! grep -q 'kirk' README.md && ! grep -q 'OPENSEARCH_INITIAL_ADMIN_PASSWORD' README.md && ! grep -q -- '-----BEGIN' README.md && grep -q 'search.caSecretName' README.md && grep -q 'opensearch-tls' README.md && grep -q 'opensearch-internal-users' README.md && grep -q 'CN=gx-opensearch-admin' README.md
- [x] 5.2 Move the `search-credential-required` README requirement to the modified text (spec delta in this change)
  check: n/a — OpenSpec delta, applied by archive

## 6. Human-run live-cluster checks (the pipeline executes none of these)

- [ ] 6.1 AC1/G1 on a throwaway cluster, README steps followed with locally issued test certificates: (a) OpenSearch starts and `_cluster/health` is green over HTTPS with the operator CA; (b) a request authenticated with the published demo admin certificate is rejected, and one with the operator admin certificate (`CN=gx-opensearch-admin`) and `securityadmin.sh` works; (c) the admin password `admin` and the demo users are rejected; (d) `kubectl exec ... cat config/opensearch.yml` shows no `allow_unsafe_democertificates` or `CN=kirk`; (e) `openssl s_client -verify_hostname opensearch-cluster-master.<ns>.svc.cluster.local -CAfile ca.crt` chains; (f) the chart renders with `search.caSecretName` and fails without it
  check: n/a — human-run live-cluster check before push
- [ ] 6.2 G1 end to end: build `groundx` and `process` locally from cashbot-go with the GX-90 change, side-load them (for example `kind load docker-image`), set `groundx.image` and `process.image`, then ingest a document and run a search; also confirm a pod with the CA removed refuses to connect
  check: n/a — human-run live-cluster check before push

## 7. Gate

- [ ] 7.1 Run `.build/bin/validate-helm.sh` from the git pre-push gate with helm v3.19.0; on a snapshot difference hand-patch, verify without `-u`, then run `verify-helm-snapshots.py`
  check: n/a — verification run of the CI gate in the verify phase; the behavior it guards is checked by tasks 1.1, 2.1, 3.1 and 4.1

See workspace `openspec/changes/` for cross-service coordination (the cashbot-go change that verifies the server certificate and reads `ai.aws.search.caFile`, the studio-harness docs, and deferred items).
