## Why

The documented chart-deployed OpenSearch install (README `-f helm/values/opensearch/values.yaml`) sets no TLS certificates, so the image runs OpenSearch's bundled demo security configuration. That configuration trusts an admin certificate (`CN=kirk`) whose private key is published in OpenSearch's public source, so any workload that reaches the OpenSearch port is admin regardless of the admin password GX-75 made private. The GroundX services also do not verify the OpenSearch server certificate today, so replacing the certificates alone would leave the connection unauthenticated (that client change lives in cashbot-go).

## What Changes

- The documented OpenSearch install uses an operator-supplied CA, node certificate and admin certificate, each read from a Kubernetes Secret. The install does not enable the demo security configuration or `plugins.security.allow_unsafe_democertificates`, and the `CN=kirk` admin DN is not trusted. Edited in `src/groundx/values/opensearch/values.yaml` and mirrored byte-identical to `helm/values/opensearch/values.yaml`.
- New operator-supplied search CA Secret key in the GroundX chart (`values.yaml` + `values.schema.json`). The CA is mounted read-only into every golang workload (groundx, process) and its path is rendered as `ai.aws.search.caFile` in `config.yaml`. The same key serves a private-CA `search.existing`.
- **BREAKING (render-time):** when the chart deploys the in-cluster OpenSearch and no search CA secret is set, the chart fails to render with a message naming the key to set (same pattern as the GX-75 password guard). Existing installs must set the key before upgrading.
- README: OpenSearch install section, demo-TLS caveat, CA key, image requirement (only groundx/process images carrying the GX-90 cashbot-go change read the key; older images ignore it and keep skipping verification), node certificate SAN `<serviceName>-cluster-master.<ns>.svc.cluster.local`, restart-based rotation (restart groundx, then process), and "Upgrading an Existing Install" step 3 moved off `kirk.pem` to the operator admin certificate plus a pre-upgrade re-certify step for groundx and process.
- helm-unittest coverage for the guard fail and pass cases, the volume/mount and the rendered `caFile`; snapshots hand-patched, never regenerated with `-u`.
- Prepared, human-run commands for the acceptance gate (demo cert rejected, operator admin cert works, rendered `opensearch.yml` has no demo settings, node cert chains with hostname, locally built groundx/process images index and search). Nothing is executed by the pipeline.
- No certificate or key material is committed. Remains persisted at rest and unchanged: the OpenSearch data volume and its existing users; behavior changes only in which certificates are trusted.

## Capabilities

### New Capabilities

- `search-tls-operator-certificates`: the documented OpenSearch install and the GroundX chart trust only operator-supplied certificates; the search CA key, its mount, the `caFile` config path and the render guard.

### Modified Capabilities

(none; `search-credential-required` covers passwords, which stay as GX-75 left them)

## Impact

- groundx-on-prem (base `0.2.8`, PRIVILEGED: authoring and render-only checks such as `helm template`/`lint`/`unittest`; no deploy or cluster-mutating command): `src/groundx/values/opensearch/values.yaml`, `src/groundx/values.yaml`, `src/groundx/values.schema.json`, `templates/_helpers/services/search.tpl`, `templates/resources/config-yaml.yaml`, `templates/app/golang.yaml`, `src/groundx/tests/`, the `helm/` mirror of each changed file (verified by the `validate-helm.sh` mirror check), `README.md`.
- Producer contract for the same-level consumer cashbot-go: the search CA Secret key, the mount path and `ai.aws.search.caFile`; exact names are fixed in design.
- Out of scope: OpenSearch passwords (GX-75), the application user's `all_access` role, a NetworkPolicy, externally hosted OpenSearch hardening, the `src/opensearch` wrapper chart, release tarballs, regeneration of `groundx-agent-harness`.
- Open for design: a spike on how the image disables the demo installer, whether `OPENSEARCH_INITIAL_ADMIN_PASSWORD` still applies, whether `restapi.roles_enabled` still includes `all_access`, and how upstream chart 2.23.1 mounts Secrets.

## Amendments

2026-10-26 (review round 1): the `search-credential-required` delta and the live spec `openspec/specs/search-credential-required/spec.md` regain the GX-75 `cluster.search` qualifier (the Terraform operator takes both passwords as values only when `cluster.search` is true; an ingest-only install needs neither), which this change's rewrite had dropped. The README upgrade steps also make removing the image's demo users a required step independent of admin-password rotation.
