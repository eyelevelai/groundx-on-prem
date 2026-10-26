# Tasks — GX-130: deliver the operator CA whenever `fileAccess.caSecretName` is set

Checks run from the repo root via `bash -c`. Helm commands use `"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}"` and first confirm helm v3.19.0; the unittest check also confirms the helm-unittest plugin version pinned in `.build/HELM_UNITTEST_VERSION`. No check uses `helm unittest -u`, prints a rendered manifest, or executes a file inside this repo. The unittest check runs on a `mktemp -d` copy of `src/groundx` that holds the throwaway Google-OCR fixture, then deletes the copy.

Mirror rule: every template edit under `src/groundx/templates/` is copied byte for byte into `helm/templates/` in the same task. No `__snapshot__` file changes in this change.

The full gate, `.build/bin/validate-helm.sh`, runs as the `groundx-on-prem` pre-push hook at hand-off; no task below runs it.

## Rollout sequence (secret change, no SQL)

1. The operator creates the CA Secret in the chart namespace, with key `ca.crt` holding a complete trust bundle (public roots plus the private CA).
2. Upgrade the chart with `fileAccess.caSecretName` set; every application workload's pods are replaced.
3. Confirm every pod is Ready.
4. Only then roll the cashbot-go release that enforces certificate verification.

Rollback: clear `caSecretName` and upgrade, or `helm rollback`; never disable certificate verification in cashbot-go.

## 1. Thin slice: the CA reaches every application workload

- [x] 1.1 In `src/groundx/templates/_helpers/app/file-access.tpl`, change the condition of `groundx.fileAccess.caEnv`, `groundx.fileAccess.caMount` and `groundx.fileAccess.caVolume` to `dig "caSecretName" "" (.Values.fileAccess | default dict)` (dropping the `groundx.fileAccess.create` check), and read `caVolume`'s `secretName` through the same `dig`; copy the file to `helm/templates/_helpers/app/file-access.tpl` (design decision 2)
  check: H="${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}"; "$H" version --short | grep -q '^v3\.19\.0+' || exit 1; for c in src/groundx helm; do r=$("$H" template t "$c" --set fileAccess.enabled=false --set fileAccess.caSecretName=private-ca --show-only templates/app/golang.yaml) || exit 1; n=$(printf '%s\n' "$r" | grep -c '^kind: Deployment$'); [ "$n" -gt 0 ] && [ "$(printf '%s\n' "$r" | grep -c 'name: SSL_CERT_FILE$')" -eq "$n" ] && [ "$(printf '%s\n' "$r" | grep -c 'mountPath: /var/run/groundx/file-access$')" -eq "$n" ] && [ "$(printf '%s\n' "$r" | grep -c 'secretName: "private-ca"$')" -eq "$n" ] || exit 1; done; diff -r src/groundx/templates helm/templates
- [x] 1.2 In `src/groundx/templates/app/metrics.yaml`, add the three `{{- with include "groundx.fileAccess.ca…" $ }}` blocks in the form `golang.yaml` uses: `caEnv` after the `LISTEN_PORT` entry (`nindent 12`), `caMount` first in `volumeMounts` (`nindent 12`), `caVolume` first in `volumes` (`nindent 8`); copy the file to `helm/templates/app/metrics.yaml`. Covered by the `file_settings_test.yaml` case "CA bundle reaches the metrics and Go Deployments while file access is disabled", already authored; the `metrics_test.yaml` and `golang_test.yaml` snapshot suites must pass unchanged (design decisions 3 and 4)
  check: H="${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}"; "$H" version --short | grep -q '^v3\.19\.0+' && "$H" plugin list | grep -Eq "^unittest[[:space:]]+$(sed 's/^v//' .build/HELM_UNITTEST_VERSION)[[:space:]]" || exit 1; d=$(mktemp -d) || exit 1; cp -R src/groundx/. "$d"/ && mkdir -p "$d/files/ocr" && printf '{\n  "type": "service_account",\n  "project_id": "groundx-helm-test",\n  "private_key_id": "test",\n  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",\n  "token_uri": "https://oauth2.googleapis.com/token"\n}\n' > "$d/files/ocr/gcv-test.json" && "$H" unittest -f tests/file_settings_test.yaml -f tests/metrics_test.yaml -f tests/golang_test.yaml "$d"; rc=$?; rm -r -- "$d"; [ "$rc" -eq 0 ] && diff -r src/groundx/templates helm/templates && [ -z "$(git status --porcelain -- src/groundx/tests/__snapshot__)" ]

## 2. Operator doc

- [x] 2.1 In `docs/agents/private-file-access.md`: in the opening paragraph (lines 3-5) change "workloads and ingress manifests remain unchanged while it is disabled." to end "…remain unchanged while it is disabled, except that a set `caSecretName` still delivers its CA bundle (see below)."; in the `caSecretName` bullet (lines 53-59) say the chart sets `SSL_CERT_FILE` "in every GroundX application workload, the metrics server and the migration Job included, whether or not file access is enabled", and add "Create the Secret in the chart namespace before the install or upgrade that sets `caSecretName`; a missing Secret or `ca.crt` key stops those pods from starting." Keep the existing complete-bundle, empty-value and restart-after-rotation sentences
  check: t=$(tr -s ' \n' '  ' < docs/agents/private-file-access.md) && grep -qF 'whether or not file access is enabled' <<<"$t" && grep -qF 'the metrics server' <<<"$t" && grep -qF 'Create the Secret in the chart namespace before' <<<"$t" && ! grep -qF 'remain unchanged while it is disabled. Enabling' <<<"$t"

See workspace `openspec/changes/gx-130-cashbot-go-verify-outbound-https-and-redis-server/tasks.md` for cross-service coordination and deferred items (the cashbot-go release order and the `groundx-studio-harness` documentation of `caSecretName`).
