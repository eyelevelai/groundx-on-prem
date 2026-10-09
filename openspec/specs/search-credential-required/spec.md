# search-credential-required Specification

## Purpose
Require operators to supply the OpenSearch application and admin passwords instead of relying on a chart default.
## Requirements
### Requirement: Search passwords are operator supplied when search is in use
When `mode` is not `ingest`, the chart SHALL accept `search.password` and `search.privilegedPassword` from values and SHALL equally accept either one empty or absent, because the operator may supply it through the cluster credentials Secret `eyelevel-secret-credentials`. An empty or absent value SHALL render without error, and the rendered GroundX config SHALL omit that credential's `password:` line instead of carrying any other value. This applies to `src/groundx` and to the `helm/` mirror. The behavior is implemented in the template (search helpers), not in `values.schema.json`, so that it can be gated on mode. Both keys SHALL stay in `values.yaml` as empty strings because the schema requires them.

Invariant: the chart never renders a search credential that it chose itself or that is a published default; an unset credential is rendered as unset so the cluster Secret can supply it. Removing the empty-value failure while adding or keeping a helper fallback value does not satisfy it.

#### Scenario: Empty application password renders and is omitted (polarity: accept and enqueue; must not block)
- **WHEN** the chart is rendered with `mode` unset or `all`, `search.password` set to an empty string, and `search.privilegedPassword` set to a non-empty value
- **THEN** the render succeeds and `config-yaml-map` is produced
- **AND** the rendered `ai.aws.search` block has no `password:` line, and the `init.search` block still carries the supplied admin password

#### Scenario: Empty admin password renders and is omitted (polarity: accept and enqueue; must not block)
- **WHEN** the chart is rendered with `mode` unset or `all`, `search.privilegedPassword` set to an empty string, and `search.password` set to a non-empty value
- **THEN** the render succeeds and `config-yaml-map` is produced
- **AND** the rendered `init.search` block has no `password:` line, and the `ai.aws.search` block still carries the supplied application password

#### Scenario: Both passwords empty carry no search password, not a fallback (polarity: accept and enqueue; catches)
- **WHEN** the chart is rendered with `mode` unset or `all` and both search passwords empty or absent, including with `search.existing.url` set
- **THEN** the render succeeds
- **AND** neither the `ai.aws.search` block nor the `init.search` block carries a `password:` line (the counterexample that satisfies "the failure was removed" while a helper default re-introduces a built-in password)

#### Scenario: A published default is still rejected next to an empty credential (polarity: reject before state; catches)
- **WHEN** the chart is rendered with `mode` not `ingest`, one search password set to a value whose SHA-256 is in `search.bannedPasswordHashes`, and the other search password empty
- **THEN** the render fails naming the key that holds the published default
- **AND** no `config-yaml-map` Secret is produced
- **AND** the same holds when every Golang service is disabled, because the check does not depend on a service being rendered

#### Scenario: Supplied passwords render unchanged (polarity: accept and enqueue; must not block; backward compatibility during rollout)
- **WHEN** the chart is rendered with `mode` not `ingest` and both passwords set to non-empty, non-default test values
- **THEN** the render succeeds and `config-yaml-map` carries exactly those two values
- **AND** an existing install that sets both keys to its current non-default OpenSearch credentials renders the same configuration it rendered before the upgrade

### Requirement: A published default search password is rejected
When `mode` is not `ingest`, the chart SHALL fail the render if `search.password` or `search.privilegedPassword` is a published default password, so that an upgrade which silently keeps the old default (for example `helm upgrade --reuse-values`) does not deploy. The rejected set SHALL be matched by SHA-256 against `search.bannedPasswordHashes` (default: the published default's hash), so no tracked file stores the password itself. This applies to `src/groundx` and to the `helm/` mirror.

#### Scenario: A published default is rejected (polarity: reject before state; catches)
- **WHEN** the chart is rendered with `mode` not `ingest` and `search.password` (or `search.privilegedPassword`) set to a value whose SHA-256 is in `search.bannedPasswordHashes`
- **THEN** the render fails with a message that the password must not be a published default
- **AND** no `config-yaml-map` Secret is produced

#### Scenario: A non-default password renders (polarity: accept and enqueue; must not block)
- **WHEN** the chart is rendered with `mode` not `ingest` and both passwords set to non-empty values not present in `search.bannedPasswordHashes`
- **THEN** the render succeeds

### Requirement: Ingest mode renders no search password
When `mode` is `ingest`, the chart SHALL render without any search password set, and SHALL NOT render a search password even when one is supplied.

#### Scenario: Ingest renders with no search passwords (polarity: accept and enqueue; must not block)
- **WHEN** the chart is rendered with `mode: ingest` and both search passwords empty
- **THEN** the render succeeds

#### Scenario: Ingest does not leak a supplied password (polarity: skip unrelated repair path)
- **WHEN** the chart is rendered with `mode: ingest` and both passwords set to distinctive sentinel values
- **THEN** neither sentinel appears anywhere in the rendered `config-yaml-map`

### Requirement: No tracked file carries a working search password
The literal that the chart previously published as the default OpenSearch password SHALL NOT appear in any tracked file of `groundx-on-prem`: not in `src/groundx` or `helm/` values, templates, or snapshots, not in either OpenSearch seed values file, not in `sample.values.yaml`, not in either `values.aws.services.yaml`, and not in the Terraform operator defaults or example tfvars. The check is against the literal taken from the pinned base revision, so the literal is never written into the repository or its logs. Values that remain after the removal (existing OpenSearch data, users and passwords on running clusters) are untouched by the chart.

#### Scenario: Literal is absent from every tracked file (polarity: reject before state; catches)
- **WHEN** the literal is read from the pinned base revision and searched for across all tracked and untracked-unignored files
- **THEN** there are zero matches
- **AND** the search refuses to pass if the literal could not be read from the base revision (fail closed)

#### Scenario: OpenSearch seed values do not seed a password (polarity: reject before state)
- **WHEN** the seed values file used by the README OpenSearch install is inspected
- **THEN** it defines no `OPENSEARCH_INITIAL_ADMIN_PASSWORD` value, so the README install cannot start OpenSearch with a password the operator did not supply

### Requirement: README takes operator-supplied OpenSearch passwords
The README `### OpenSearch` install step SHALL take an operator-supplied admin password (passed to the OpenSearch release as `OPENSEARCH_INITIAL_ADMIN_PASSWORD`) and state that the same value must be provided to GroundX as `search.privilegedPassword` in values or as `SEARCH_INIT_PASSWORD` in the cluster credentials Secret. The README `### Configuration` minimal-keys block SHALL list `search.password` and `search.privilegedPassword` as set through values or the cluster credentials Secret when `mode` is not `ingest`, and the paragraph after it SHALL state that:
- each search credential can be set via values or via the Secret (`SEARCH_PASSWORD`, `SEARCH_INIT_PASSWORD`), as the `MYSQL_*` keys in the sample Secret do for `db`;
- the Secret route requires `cluster.secrets` to list `eyelevel-secret-credentials`;
- passwords delivered through the Secret are not render-validated by the chart, because the published-default check sees values only;
- the Secret route applies to the direct-helm route, and the Terraform operator still takes both passwords as values when `cluster.search` is true (an ingest-only install, `cluster.search = false`, needs neither).

The README SHALL carry a migration note for existing installs: an existing OpenSearch keeps the admin password it was first initialised with, so, when those are non-default, set the admin password (`search.privilegedPassword` or `SEARCH_INIT_PASSWORD`) to the current admin password and the application password (`search.password` or `SEARCH_PASSWORD`) to the current application password, then rotate (if either current value is a published default the chart rejects it when it is supplied through values, so rotate the admin off it first and choose a new application password); a wrong admin password makes the GroundX API crash-loop at startup when it has to create or update its user (a first install or an application-password change), and is otherwise silent rather than fail the render.

#### Scenario: OpenSearch step asks for a password (polarity: reject before state)
- **WHEN** the README `### OpenSearch` section is read
- **THEN** it names `OPENSEARCH_INITIAL_ADMIN_PASSWORD`, `search.privilegedPassword` and `SEARCH_INIT_PASSWORD`
- **AND** it contains no password value

#### Scenario: Configuration block lists both passwords as values or Secret (polarity: reject before state)
- **WHEN** the README `### Configuration` section is read
- **THEN** it lists `search.password` and `search.privilegedPassword` as set through values or the cluster credentials Secret when `mode` is not `ingest`
- **AND** it no longer says rendering fails until both are set

#### Scenario: README states the Secret route and its limits (polarity: reject before state)
- **WHEN** the README `### Configuration` section is read
- **THEN** it names `SEARCH_PASSWORD`, `SEARCH_INIT_PASSWORD` and `cluster.secrets`
- **AND** it states that Secret-delivered passwords are not render-validated and that the Terraform operator still takes the passwords as values when `cluster.search` is true

### Requirement: Terraform operator requires both search passwords when search is enabled
The Terraform operator module SHALL define `variable "search"` with a default whose `password` and `root_password` are empty strings, and validations that reject an empty or angle-bracket-placeholder `password` or `root_password` only when `cluster.search` is true. An ingest-only install (`cluster.search = false`) SHALL NOT be required to supply either password. The module SHALL declare `required_version = ">= 1.9"` because the validations reference `var.cluster`. The values SHALL still flow to the generated GroundX config and to the OpenSearch release. `env.tfvars.example` and `env.tfvars.example-openshift` SHALL show placeholders for all four fields, with no colon in a placeholder.

#### Scenario: Missing search variable is rejected when search is enabled (polarity: reject before state)
- **WHEN** `cluster.search` is true and Terraform evaluates the `search` variable with no value supplied
- **THEN** validation fails on the empty default `password`

#### Scenario: Ingest-only install needs no search passwords (polarity: accept and enqueue; must not block)
- **WHEN** `cluster.search` is false and `search.password` and `search.root_password` are empty
- **THEN** variable validation passes

#### Scenario: Empty password strings are rejected (polarity: reject before state; catches)
- **WHEN** `cluster.search` is true and `search.password` is an empty string, and separately when `search.root_password` is an empty string or an angle-bracket placeholder
- **THEN** variable validation fails in each case
- **AND** an empty string is not treated as "supplied"

#### Scenario: Supplied passwords are accepted (polarity: accept and enqueue; must not block)
- **WHEN** `cluster.search` is true and `password` and `root_password` are non-empty, non-placeholder values
- **THEN** variable validation passes and the values reach `init/config/golang.tf` and `services/search/opensearch.tf`

### Requirement: Every render gate supplies test-only search passwords from one fixture
Every CI, gate, and declared render command that renders a non-ingest configuration SHALL keep supplying test-only search passwords from a single literal-free fixture under `src/groundx/tests/files/`, so the rendered output and the helm-unittest snapshots carry explicit test credentials. Nothing SHALL be added to `values/minikube` or any install example to satisfy this. helm-unittest snapshots SHALL NOT depend on a chart default, and the chart no longer fails a render that omits the fixture.

#### Scenario: Gate and declared commands use the fixture (polarity: reject before state)
- **WHEN** `.build/bin/validate-helm.sh` runs on the changed chart
- **THEN** it passes, and the workflow, `service.yaml`, `openspec/config.yaml` and `AGENTS.md` render commands reference the fixture

#### Scenario: A render without the fixture succeeds and carries no search password (polarity: accept and enqueue)
- **WHEN** a non-ingest render is attempted without search passwords
- **THEN** it succeeds, because the operator may supply the passwords through the cluster credentials Secret
- **AND** it is not satisfied by a default: the rendered config carries no search `password:` line

### Requirement: The sample cluster credentials Secret carries inert search keys
`src/groundx/prereqs/secret/values.yaml` and its `helm/prereqs/secret/values.yaml` copy SHALL define `SEARCH_PASSWORD` (the application user password, read by the GroundX API into `AI.AWS.Search.Password`) and `SEARCH_INIT_PASSWORD` (the OpenSearch admin password, read into `Init.Search.Password`) with empty string values, so applying the sample unchanged supplies no working credential. The chart SHALL need no template change to deliver them: the Secret reaches the Golang pods through `envFrom` when `cluster.secrets` lists `eyelevel-secret-credentials`, and not otherwise. The route depends on the GroundX API image (cashbot-go, same level) reading these variables when its values keys are empty; operators who keep setting values are unaffected in either rollout order.

#### Scenario: The sample defines both keys with no value (polarity: reject before state; catches)
- **WHEN** `src/groundx/prereqs/secret/values.yaml` and `helm/prereqs/secret/values.yaml` are inspected
- **THEN** each defines `SEARCH_PASSWORD` and `SEARCH_INIT_PASSWORD`, both with empty values, and the two files are byte-identical
- **AND** neither carries a non-empty value for either key (a non-empty sample value would become a working, unvalidated search credential for anyone who applies the sample unchanged)

#### Scenario: The Secret reaches the API pod only when listed in cluster.secrets (polarity: accept and enqueue; skip unrelated repair path)
- **WHEN** the chart is rendered with `cluster.secrets: [eyelevel-secret-credentials]` and empty search passwords
- **THEN** the `groundx` Deployment's container carries an `envFrom` entry referencing `eyelevel-secret-credentials`
- **AND** with `cluster.secrets` unset the container carries no `envFrom`

