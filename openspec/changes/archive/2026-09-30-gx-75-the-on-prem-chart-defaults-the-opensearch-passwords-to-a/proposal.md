## Why

The chart, in a public repository, ships one fixed OpenSearch password (the literal) as the default for both `search.password` (application user) and `search.privilegedPassword` (admin user). The helpers in `templates/_helpers/services/search.tpl` fall back to it when the keys are absent, and the OpenSearch seed values, the README install step (which points at the seed file), sample values, AWS values, the render snapshot, and the Terraform defaults and examples repeat it. A default install therefore runs OpenSearch with credentials anyone can read. GX-75 makes the operator choose the passwords: with search in use, the chart refuses to render without them.

## What Changes

- **BREAKING (operator contract):** `search.password` and `search.privilegedPassword` have no working default in `src/groundx` and the `helm/` mirror (base `0.2.7`). Both keys stay in `values.yaml` as empty strings because `values.schema.json` requires them.
- When `mode` is not `ingest` (search in use, including `search.enabled: false` and `search.existing`), an empty or absent value for either key fails the render and the message names the offending key. The check lives in the template (search helpers and `config-yaml.yaml`), not in `values.schema.json`, so it can be gated on mode.
- With `mode: ingest`, no search password is rendered and no search password needs to be set, even if one is supplied.
- The literal is removed from every tracked file: both `values.yaml` files, both OpenSearch seed values files, both `values.aws.services.yaml` files, `sample.values.yaml`, the `helm/` mirror, the render snapshot (hand-patched, never `helm unittest -u`, per repo `AGENTS.md`), and Terraform defaults and examples. `git grep` for the literal in this repo finds nothing.
- README `### OpenSearch` takes an operator-supplied admin password and passes it as `search.privilegedPassword`; README `### Configuration` lists both search passwords as required when `mode` is not `ingest`; a migration note covers existing installs.
- Terraform operator module: `search.password` and `search.root_password` become required and empty strings are rejected; the `search` variable loses its default (so index and user become required too); `env.tfvars.example` and `env.tfvars.example-openshift` show placeholders for all four fields (no colon in placeholders).
- Tests and gates: helm-unittest suites that render `config-yaml.yaml` set test-only search passwords; new failing-render cases (empty `search.password`, separately empty `search.privilegedPassword`, absent keys) and an ingest no-password case fold into existing suites (precedent `metrics_test.yaml`). Every CI, gate, and declared render command (`.build/bin/validate-helm.sh`, `.github/workflows/helm-tests.yml`, the `verify-*` scripts, and the render checks declared in `service.yaml`, `openspec/config.yaml`, `AGENTS.md`) supplies test-only passwords from one literal-free fixture under `src/groundx/tests/files/`. Nothing is added to `values/minikube` or any install example.

**Migration note (rollout).** An existing OpenSearch keeps the admin password it was first initialised with. Upgrade by setting `search.privilegedPassword` to the current admin password and `search.password` to the current application password, then rotate. Installs that relied on the default fail to render on upgrade until both are set; that is intended. The GroundX API creates or updates `search.username` with `search.password` at startup using the admin credentials, so a wrong `search.privilegedPassword` makes the GroundX API crash-loop rather than fail the render.

**Blast radius and rollback.** Affects every environment that renders this chart with `mode` other than `ingest` and relies on the default (any dev, staging, or prod install and the Terraform operator flow). No stateful resource is modified by the chart change itself: existing OpenSearch data and users are untouched, and only the values a `helm upgrade` renders change. Rollback is `helm rollback` or pinning the previous chart version; roll-forward is supplying both passwords. Assumption from the ticket: no production install depends on the default.

**Gating premise (Gate 0 spike, before apply).** The new README path assumes the seed image honors `OPENSEARCH_INITIAL_ADMIN_PASSWORD` on a fresh volume and keeps the first admin password on restart. This is checked with a throwaway local probe before implementation; if falsified, the plan is re-opened (operator-supplied internal-users hash or a stock OpenSearch image), not pre-built here.

**Overlap with `gx-17-config-maps-as-secrets`.** That change renders `config-yaml-map` (which carries the `search.*` passwords) as a Secret in place with byte-identical content. On this branch `config-yaml.yaml` is already `kind: Secret`. GX-75 does not change resource kinds, names, mounts, or Secret handling; it changes only which values are allowed to reach that file (fail instead of fall back to the literal). No conflict: both edit `config-yaml.yaml`, in different places, and GX-75 keeps GX-17's byte-identical property for any render that supplies passwords. Supporting an operator-supplied `existingSecret` for search is out of scope (out of scope); search passwords come only from values, matching db, cache, and file.

Open design questions: none.

## Capabilities

### New Capabilities
- `search-credential-required`: with search in use (`mode` not `ingest`), the chart requires operator-supplied `search.password` and `search.privilegedPassword` and fails the render naming the missing key; in `mode: ingest` no search password renders; no tracked file, default, seed, sample, or Terraform default carries a working search password; Terraform requires both search passwords and rejects empty strings.

### Modified Capabilities
<!-- None. No existing spec under openspec/specs/ states a search-password requirement (grep of search/opensearch hits only database-upgrade-gate, ranker-inference-autoscaling, ranker-ingest-mode-gating, redis-authenticated-credentials, none about these passwords). -->

## Impact

- `groundx-on-prem` only (`src/groundx`, `helm/` mirror, README, `terraform/groundx-operator/operator`, CI and gate render commands, tests and snapshot). PR targets `0.2.7`.
- Cross-service touchpoint (PRODUCER): the chart values contract (operator must supply both keys; `mode: ingest` exempt). The consumer is `groundx-studio-harness` (`groundx-on-prem` skill docs and scanner), which merges after the `0.2.7` publish; it is not edited from here. `cashbot-go` is unchanged. `groundx-agent-harness` is derived and regenerated, never edited.
- No dependency changes.
