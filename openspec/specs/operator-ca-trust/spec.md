# operator-ca-trust Specification

## Purpose
TBD - created by archiving change gx-130-cashbot-go-verify-outbound-https-and-redis-server. Update Purpose after archive.
## Requirements
### Requirement: The operator CA bundle reaches every application workload whenever caSecretName is set
When `fileAccess.caSecretName` is non-empty, every GroundX application workload rendered from `templates/app/` (the Go Deployments, API, Celery, inference, the schema-migration Job and the metrics Deployment) SHALL carry all three of the following, whether `fileAccess.enabled` is true or false:

- the container environment variable `SSL_CERT_FILE` with value `/var/run/groundx/file-access/ca.crt`;
- the container volume mount `file-access-ca` at `/var/run/groundx/file-access`, read-only;
- the pod volume `file-access-ca` from the Secret named by `fileAccess.caSecretName`, projecting only the key `ca.crt` to the path `ca.crt`.

The `groundx.fileAccess.caEnv`, `groundx.fileAccess.caMount` and `groundx.fileAccess.caVolume` helpers SHALL decide on `fileAccess.caSecretName` alone. `helm/templates/` SHALL be byte-identical to `src/groundx/templates/`. No values key, environment variable, mount path or volume name is added or renamed.

Invariant: a workload's CA trust follows `fileAccess.caSecretName` alone, and the variable, the mount and the volume always appear together on the same workloads. A change that edits the helper conditions but leaves any one of the three gated on `fileAccess.enabled`, or that adds the variable to a workload without its mount and volume, does not satisfy it.

Validated by the helm-unittest case "CA bundle reaches the metrics and Go Deployments while file access is disabled" in `src/groundx/tests/file_settings_test.yaml`, run without `-u`, and by `diff -r src/groundx/templates helm/templates`.

#### Scenario: CA set with file access disabled reaches metrics and the Go services (polarity: accept and enqueue; catches)
- **GIVEN** the chart with `fileAccess.enabled` false, `fileAccess.caSecretName` set to `private-ca` and `metrics.enabled` true
- **WHEN** `helm unittest -f tests/file_settings_test.yaml` runs against `templates/app/metrics.yaml` and `templates/app/golang.yaml`
- **THEN** the `metrics` Deployment and the `groundx` Deployment each carry `SSL_CERT_FILE=/var/run/groundx/file-access/ca.crt`, the read-only `file-access-ca` mount at `/var/run/groundx/file-access`, and the `file-access-ca` volume from Secret `private-ca` with item `ca.crt`
- **AND** the case fails if any of the three helpers still requires `fileAccess.enabled`, or if the metrics Deployment carries the variable without its mount and volume (the counterexample a condition-only edit satisfies)

#### Scenario: CA set with file access enabled keeps today's workloads unchanged (polarity: accept and enqueue; must not block)
- **GIVEN** the chart with `tests/files/values.file-access.yaml` (`fileAccess.enabled` true, `caSecretName: file-store-ca`)
- **WHEN** the existing `file_settings_test.yaml` cases "gateway uses the shared Go workload with private secret and CA references" and "migration job receives the same credential and trust references on upgrades" run
- **THEN** both pass unchanged: the gateway Deployment and the migration Job still carry `SSL_CERT_FILE` and the `file-store-ca` volume

#### Scenario: Empty caSecretName adds no CA where no bundle is required (polarity: skip unrelated repair path; must not block; backward compatibility during rollout)
- **GIVEN** the chart with `fileAccess.caSecretName` empty and either an existing OpenSearch (`search.existing.url`) or `mode: ingest`
- **WHEN** the `golang_test.yaml` migration and producer cases that use an existing OpenSearch run without `-u`
- **THEN** they pass, and no workload carries `SSL_CERT_FILE` or a `file-access-ca` volume, so cashbot-go and ai-server keep system trust
- **AND** with the in-cluster OpenSearch an empty `caSecretName` no longer renders (GX-90, `search-tls-operator-certificates`), so the snapshot suites set `fileAccess.caSecretName: fixture-ca-bundle` and their workloads carry the CA

#### Scenario: The published mirror carries the same templates (polarity: accept and enqueue)
- **WHEN** `diff -r src/groundx/templates helm/templates` runs after the change
- **THEN** it reports no difference, so a chart packaged from `helm/` delivers the CA the same way

### Requirement: The operator doc states where the CA reaches and what must exist first
`docs/agents/private-file-access.md` SHALL state that a set `caSecretName` delivers the CA bundle to every GroundX application workload, the metrics server and the migration Job included, whether or not file access is enabled; that the Secret must exist in the chart namespace before the install or upgrade that sets it, because a missing Secret or `ca.crt` key stops those pods from starting; and its opening paragraph SHALL no longer say, without qualification, that workloads stay unchanged while file access is disabled. The existing guidance on a complete trust bundle, empty-value system trust and restarting consumers after rotation SHALL remain.

#### Scenario: The doc describes the widened delivery (polarity: accept and enqueue)
- **WHEN** the doc text is read with line breaks folded to spaces
- **THEN** it contains "whether or not file access is enabled", "the metrics server" and "Create the Secret in the chart namespace before"
- **AND** it no longer contains "remain unchanged while it is disabled. Enabling"

