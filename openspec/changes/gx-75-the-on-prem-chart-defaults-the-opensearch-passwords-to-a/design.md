## Goals / Non-Goals

**Goals.** With search in use, no chart render, tracked file, or Terraform input yields a search password the operator did not choose; the failure names the missing key; `mode: ingest` is unaffected.

**Non-Goals.** An operator-supplied `existingSecret` for search or any backing service (follow-up ticket); the Percona and MinIO seed defaults; changes to `cashbot-go`, the harness, or the derived agent bundle; any change to resource kinds, names, or mounts.

## Decisions

### D1. Invariant
A render with search in use never carries a search credential the operator did not supply, and no tracked file carries a working search credential. The meaning is "no default exists", not "the literal is missing from values.yaml": a surviving helper fallback or a copy in a seed, sample, snapshot, or Terraform example violates it.

### D2. The requirement lives in the template, gated on mode
`groundx.search.password` and `groundx.search.privilegedPassword` in `templates/_helpers/services/search.tpl` drop their `dig` fallback. When `groundx.ingestOnly` is `true` they return an empty string and `config-yaml.yaml` skips the two search password lines; otherwise an empty or absent value calls `fail` with a message naming the key (`search.password` / `search.privilegedPassword`, distinct so a test can tell them apart). Not in `values.schema.json`: the schema is mode-blind and GX-26 showed an unconditional required key broke most in-repo values configs. Same pattern as the `fail` guards in `templates/_helpers/app/workspace.tpl:15` and `templates/_helpers/engines.tpl:39`. `search.existing` and `search.enabled: false` still require both keys because the GroundX API authenticates to the search cluster either way.

### D3. Keys stay in values.yaml as empty strings
`values.schema.json` requires both keys, so removing them would break lint. Empty strings match how `db`, `cache`, and `file` passwords already default. `values.aws.services.yaml` (both trees) drops its two password lines; `sample.values.yaml` sets them to empty strings.

### D4. OpenSearch seed values stop seeding a password
Both seed files (`helm/values/opensearch/values.yaml`, `src/groundx/values/opensearch/values.yaml`) drop the `extraEnvs` entry. The README install passes the operator's admin password through a local, uncommitted values file readable only by the operator (`opensearch-admin.values.yaml`, `chmod 600`, an `extraEnvs` entry for `OPENSEARCH_INITIAL_ADMIN_PASSWORD` holding a placeholder), passed with a second `-f` on the same `helm install opensearch opensearch/opensearch` command so the marker the harness scan pins is kept. It is never passed with `--set`, which would expose the password in shell history and the process list. The same value goes in the GroundX chart's `search.privilegedPassword`. This decision rests on the Gate 0 spike (below).

### D5. Test fixture and hand-patched snapshot
One literal-free fixture, `src/groundx/tests/files/values.search-credentials.yaml`, carries two distinct test-only values. Suites that render `config-yaml.yaml` load it through a suite-level `values:` entry (verified to work in helm-unittest 1.1.2, precedent for suite-level `set:` in `metrics_test.yaml`); CI and gate render commands pass it with `-f`. New cases fold into the existing `resources_test.yaml` (they override the fixture with `set:` for the empty and ingest cases); the `helm/` mirror has no snapshot suite for this and gets one small `helm/tests/search_credentials_test.yaml`, since none of the existing `helm/tests` suites fit. `resources_test.yaml.snap` is hand-patched (never `helm unittest -u`, per repo AGENTS.md GX-59), replacing each literal with the fixture value of the matching key.

### D6. Terraform
`variable "search"` loses its default and gains a `validation` block rejecting empty `password` and `root_password`. There is no Terraform CI; the check is a probe on an extracted copy of the variable block through `terraform plan` (no providers needed), because `terraform validate` on the whole operator module needs provider downloads and `terraform fmt -check` already fails on this file before the change.

### D7. Compatibility class: Breaking (operator contract), mechanism is fail-fast plus migration note
The chart values contract changes for every non-ingest install that relied on the default. The compatibility mechanism is the render-time failure itself (installs cannot silently keep the old value), the README migration note, and `helm rollback` / pinning the previous chart version. No API field, migration, or database change. Rollout: publish 0.2.7 with the change; the harness guidance change merges after publish (tracked in the harness ticket flow, not here).

### D8. Gate 0 spike precedes apply
The README path assumes the seed image `public.ecr.aws/c9r4x6y5/eyelevel/opensearch:latest` honors `OPENSEARCH_INITIAL_ADMIN_PASSWORD` on a fresh volume and keeps the first admin password on restart. The main loop runs this throwaway local probe (human-gated) before apply; if falsified, D4 is re-opened rather than pre-built.
