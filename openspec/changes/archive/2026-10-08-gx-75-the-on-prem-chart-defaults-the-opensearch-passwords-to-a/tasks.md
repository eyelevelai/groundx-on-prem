## 1. Thin slice: an empty search credential renders in `src/groundx`

The suite `src/groundx/tests/search_credentials_test.yaml` is the acceptance stub for this group; it was written first and, run on 2026-10-08 before the template change, failed with "search.password is required unless mode is ingest". The old "fails when empty" cases were moved out of `src/groundx/tests/resources_test.yaml` into it and reversed.

- [x] 1.1 In `src/groundx/templates/_helpers/services/search.tpl`, remove the empty-value `fail` from `groundx.search.password` and `groundx.search.privilegedPassword`; keep the `bannedPasswordHashes` rejection and the `mode: ingest` exemption unchanged and add no fallback value
  check: export HELM319_DIR="${HELM319_DIR:?set HELM319_DIR to a helm v3.19.0 bin dir (the gate pins v3.19.0)}"; export PATH="$HELM319_DIR:$PATH" GX_ON_PREM_HELM="$HELM319_DIR/helm"; helm unittest -f tests/search_credentials_test.yaml src/groundx

## 2. Mirror to the published chart

- [x] 2.1 Mirror the `search.tpl` change by hand into `helm/templates/_helpers/services/search.tpl` so the two trees stay byte-identical
  check: export HELM319_DIR="${HELM319_DIR:?set HELM319_DIR to a helm v3.19.0 bin dir (the gate pins v3.19.0)}"; export PATH="$HELM319_DIR:$PATH" GX_ON_PREM_HELM="$HELM319_DIR/helm"; cmp src/groundx/templates/_helpers/services/search.tpl helm/templates/_helpers/services/search.tpl && helm template mirror helm --set search.password= --set search.privilegedPassword= -s templates/resources/config-yaml.yaml > /dev/null

## 3. Sample cluster credentials Secret

- [x] 3.1 Add `SEARCH_PASSWORD` and `SEARCH_INIT_PASSWORD` with empty string values to `src/groundx/prereqs/secret/values.yaml` and the identical `helm/prereqs/secret/values.yaml`; a non-empty value would be a working credential the chart cannot validate
  check: export HELM319_DIR="${HELM319_DIR:?set HELM319_DIR to a helm v3.19.0 bin dir (the gate pins v3.19.0)}"; export PATH="$HELM319_DIR:$PATH" GX_ON_PREM_HELM="$HELM319_DIR/helm"; grep -qx '  SEARCH_PASSWORD: ""' src/groundx/prereqs/secret/values.yaml && grep -qx '  SEARCH_INIT_PASSWORD: ""' src/groundx/prereqs/secret/values.yaml && cmp src/groundx/prereqs/secret/values.yaml helm/prereqs/secret/values.yaml && helm template sample src/groundx/prereqs/secret | grep -q 'SEARCH_INIT_PASSWORD'

## 4. Documentation

- [x] 4.1 Update `README.md`: the `### Configuration` minimal-keys block and the paragraph after it (values or Secret; `SEARCH_PASSWORD` and `SEARCH_INIT_PASSWORD`; `cluster.secrets` must list `eyelevel-secret-credentials`; Secret-delivered passwords are not render-validated; direct-helm route only, the Terraform operator still takes both as values), the `### OpenSearch` admin-password sentence and the migration note, per the README requirement in the spec
  check: grep -q 'SEARCH_INIT_PASSWORD' README.md && grep -q 'SEARCH_PASSWORD' README.md && grep -q 'cluster\.secrets' README.md && ! grep -q 'rendering fails until both' README.md

- [x] 4.2 Reword the `openspec/config.yaml` context line that says the search fixture "is required because the chart has no default search passwords" to say the fixture supplies explicit test credentials
  check: n/a — OpenSpec context wording, no behavior

## 5. Gate

- [x] 5.1 Run `.build/bin/validate-helm.sh` with the pinned helm; if any snapshot differs, hand-patch it and verify without `-u` followed by `verify-helm-snapshots.py` (`AGENTS.md`, GX-59), never regenerate
  check: n/a — verification run of the CI gate in the verify phase; the behavior it guards is checked by tasks 1.1, 2.1 and 3.1

See workspace `openspec/changes/` for cross-service coordination (the cashbot-go change that reads `SEARCH_PASSWORD` and `SEARCH_INIT_PASSWORD`, the Terraform operator staying on values, the harness follow-up) and deferred items.
