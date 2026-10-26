Motivation and blast radius are in `proposal.md`; requirements are in `specs/operator-ca-trust/spec.md`.

## Goals / Non-Goals

**Goals:**

- An operator can give every GroundX application workload, metrics included, a private CA bundle through the existing `fileAccess.caSecretName`, without enabling file access, before the cashbot-go release that enforces certificate verification rolls out.
- Installs that leave `caSecretName` empty render the same manifests as before.

**Non-Goals:**

- No new values key, environment variable, mount path, volume name or mechanism, and no rename of the `fileAccess.` prefix.
- No check that the Secret exists at render time.
- Bundled OpenSearch demo certificates (GX-90) and ai-server Celery Redis verification (GX-131). ai-server pods receive the variable, but whether each Python client honors it is not claimed here.
- The bundled Redis and its exporter (`templates/services/`) are backing services, not GroundX application clients, and are not changed.

## Decisions

### 1. Invariant

A workload's CA trust follows `fileAccess.caSecretName` alone, and `SSL_CERT_FILE`, the `file-access-ca` mount and the `file-access-ca` volume always appear together on the same workloads. The spec carries one scenario that catches a condition-only edit (file access disabled, all three asserted on the metrics and `groundx` Deployments) and two that must not block (file access enabled keeps today's output; an empty key keeps the committed snapshots).

### 2. The three helpers key on `caSecretName` through a nil-safe lookup

`groundx.fileAccess.caEnv`, `caMount` and `caVolume` change their condition from `and (eq (include "groundx.fileAccess.create" .) "true") (not (empty .Values.fileAccess.caSecretName))` to `dig "caSecretName" "" (.Values.fileAccess | default dict)`, and `caVolume`'s `secretName` reads the value the same way. Today the `and` stops before `.Values.fileAccess.caSecretName` when `fileAccess` is unset or null; once the `create` check is gone that reference would fail the render, so the lookup uses the same `dig ... (.Values.fileAccess | default dict)` form that `groundx.fileAccess.create` already uses (`src/groundx/templates/_helpers/app/file-access.tpl:2`).

Alternative considered: keep `.Values.fileAccess.caSecretName` because `values.yaml` defines `fileAccess`. Rejected: an override file that sets `fileAccess: null` would fail to render where it renders today.

### 3. The metrics Deployment includes the helpers in the same form as the Go workloads

`templates/app/metrics.yaml` adds the three `{{- with include "groundx.fileAccess.ca…" $ }}` blocks used by `api.yaml` and `golang.yaml`: the variable after `LISTEN_PORT` at the end of its static `env` list, the mount first in `volumeMounts`, the volume first in `volumes`. With an empty key each block renders nothing, so the metrics snapshots do not change. The metrics server has its own Redis settings, including the `ssl` flag (`src/groundx/templates/resources/config-yaml.yaml:368-370`), and waits for the cache (`src/groundx/templates/_helpers/app/metrics.tpl:103`). It is the only workload under `templates/app/` without the helpers.

### 4. One non-snapshot test case, snapshots untouched

The acceptance case lives in `src/groundx/tests/file_settings_test.yaml`, which has no `__snapshot__` file, so adding it cannot cause snapshot churn. It lists `templates/app/golang.yaml` and `templates/app/metrics.yaml` on the test (not the suite), and each assertion names its `template` and selects on `spec.template.metadata.labels.app` (`metrics`, `groundx`), following the GX-75 conventions in `openspec/config.yaml`. That empty-key renders are unchanged is shown by running the `metrics_test.yaml` and `golang_test.yaml` snapshot suites without `-u` on a copy of the chart, and by `git status --porcelain` on `src/groundx/tests/__snapshot__/` being empty. No `.snap` file is regenerated or hand-patched.

### 5. Mirror and gate

`helm/templates/_helpers/app/file-access.tpl` and `helm/templates/app/metrics.yaml` are copied byte for byte from `src/groundx/`, checked with `diff -r src/groundx/templates helm/templates`. Task checks run helm v3.19.0 (`GX_ON_PREM_HELM`, else `~/.local/bin/helm-v3.19.0`) and the helm-unittest plugin at `.build/HELM_UNITTEST_VERSION`. They run the suites on a `mktemp -d` copy of `src/groundx` holding the throwaway Google-OCR fixture, and never execute a script inside the repo. The full gate, `.build/bin/validate-helm.sh`, runs as the pre-push hook.

### 6. Compatibility class: Additive, re-confirmed against the code

With `caSecretName` empty the three helpers render nothing. The key does not exist at the released `0.2.7` tag (`git grep caSecretName refs/tags/0.2.7 -- src/groundx helm` finds nothing), so an upgrade from 0.2.7 changes these manifests only when the operator sets it. On the unreleased 0.2.8 line, output changes only when `caSecretName` is set: with file access disabled every application workload gains the mount (today none does), and with file access enabled the metrics Deployment gains it. The values schema, key names, mount path and volume name stay the same. Producer contract shapes confirmed; see `contract.md` for the full shapes.

### 7. No ADR

The change widens a condition on an existing, reversible mechanism, so an ADR is not warranted.

## Rollout and blast radius

- **Who redeploys.** Any cluster installed or upgraded from the 0.2.8 line. With `caSecretName` empty, no rendered workload changes. With it set, every application workload's pod template changes and its pods are replaced on upgrade under each Deployment's existing strategy. The schema-migration Job runs with the mount on the upgrade that sets the key.
- **Order.** (1) Create the CA Secret, with key `ca.crt` holding a complete trust bundle (public roots plus the private CA), in the chart namespace. (2) Upgrade the chart with `fileAccess.caSecretName` set. (3) Confirm every pod is Ready. (4) Only then roll the cashbot-go release that enforces certificate verification.
- **Stateful resources.** The change adds a read-only Secret volume and one variable. It does not touch stateful resources, volume claims or stored data.
- **Availability.** Pods that cannot mount the Secret do not start, and the upgrade can take old pods down before the new ones fail, so creating the Secret first (step 1) is what keeps the upgrade safe.
- **Rotation.** Go loads its system roots once per process (`once.Do(initSystemRoots)` in Go 1.26.4 `src/crypto/x509/root.go:23,31-32`; `loadSystemRoots` reads `SSL_CERT_FILE` in `root_unix.go:32-36`), so a rotated bundle needs a pod restart. The doc already says so.
- **Rollback.** Clear `caSecretName` and upgrade again, or `helm rollback` to the previous revision. Do not roll back by disabling certificate verification in cashbot-go.

## Risks / Trade-offs

- [A Secret or `ca.crt` key is missing] → every pod that mounts it fails to start. Mitigation: the doc requires creating the Secret first, and the rollout order confirms Ready before cashbot-go rolls. A render-time `lookup` check is out of scope: no new mechanism, and `lookup` is empty under `helm template`.
- [A bundle holding only the private CA] → `SSL_CERT_FILE` replaces the default bundle file (Go 1.26.4 `root_unix.go:35-37`), so calls to public HTTPS endpoints can fail. Go still scans the certificate directories (`root_unix.go:52-53`), but whether those hold public roots depends on the image, and other runtimes differ. Mitigation: the doc already requires a complete trust bundle.
- [The `fileAccess.` prefix and `file-access` paths now cover more than file access] → the names are misleading. Accepted: renaming would break installs already on the 0.2.8 line and add a new key, which the source-of-truth rules exclude.
- [A Python client in ai-server ignores `SSL_CERT_FILE`] → that client keeps its own trust. Tracked in GX-131.
