## ADDED Requirements

### Requirement: Search passwords are operator supplied when search is in use
When `mode` is not `ingest`, the chart SHALL require the operator to supply both `search.password` and `search.privilegedPassword`. An empty or absent value for either key SHALL fail the render with a message that names the offending key. This applies to `src/groundx` and to the `helm/` mirror. The requirement is enforced in the template (search helpers and `config-yaml.yaml`), not in `values.schema.json`, so that it can be gated on mode. Both keys SHALL stay in `values.yaml` as empty strings because the schema requires them.

Invariant: a render in which search is in use never carries a search credential the operator did not supply. Removing the literal from the values files while leaving a helper fallback in place does not satisfy it.

#### Scenario: Empty application password is rejected (polarity: reject before state)
- **WHEN** the chart is rendered with `mode` unset or `all`, `search.password` set to an empty string, and `search.privilegedPassword` set to a non-empty value
- **THEN** the render fails and the error names `search.password`
- **AND** no `config-yaml-map` Secret is produced

#### Scenario: Empty admin password is rejected (polarity: reject before state)
- **WHEN** the chart is rendered with `mode` unset or `all`, `search.privilegedPassword` set to an empty string, and `search.password` set to a non-empty value
- **THEN** the render fails and the error names `search.privilegedPassword`
- **AND** no `config-yaml-map` Secret is produced

#### Scenario: Chart defaults alone are rejected (polarity: reject before state; catches)
- **WHEN** the chart is rendered with its own `values.yaml` and no search password overrides
- **THEN** the render fails naming `search.password`
- **AND** the render does not fall back to any built-in password (the counterexample that satisfies "literal removed from values.yaml" while a helper `dig` fallback still renders)

#### Scenario: Externally hosted search still needs both passwords (polarity: reject before state)
- **WHEN** the chart is rendered with `search.existing.url` set (or `search.enabled: false`) and either password empty
- **THEN** the render fails naming the empty key, because the GroundX API uses the admin credential to provision `search.username` when the application login is rejected

#### Scenario: Supplied passwords render unchanged (polarity: accept and enqueue; must not block; backward compatibility during rollout)
- **WHEN** the chart is rendered with `mode` not `ingest` and both passwords set to non-empty test values
- **THEN** the render succeeds and `config-yaml-map` carries exactly those two values
- **AND** an existing install that sets both keys to its current non-default OpenSearch credentials renders the same configuration it rendered before the upgrade (an install still on a published default must choose new credentials, which the reject requires)

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
The README `### OpenSearch` install step SHALL take an operator-supplied admin password (passed to the OpenSearch release as `OPENSEARCH_INITIAL_ADMIN_PASSWORD`) and state that the same value must be set as `search.privilegedPassword` in the GroundX values. The README `### Configuration` minimal-keys block SHALL list `search.password` and `search.privilegedPassword` as required when `mode` is not `ingest`. The README SHALL carry a migration note for existing installs: an existing OpenSearch keeps the admin password it was first initialised with, so, when those are non-default, set `search.privilegedPassword` to the current admin password and `search.password` to the current application password, then rotate (if either current value is a published default the chart rejects it, so rotate the admin off it first and choose a new application password); a wrong `search.privilegedPassword` makes the GroundX API crash-loop at startup when it has to create or update its user (a first install or an application-password change), and is otherwise silent rather than fail the render.

#### Scenario: OpenSearch step asks for a password (polarity: reject before state)
- **WHEN** the README `### OpenSearch` section is read
- **THEN** it names `OPENSEARCH_INITIAL_ADMIN_PASSWORD` and `search.privilegedPassword`
- **AND** it contains no password value

#### Scenario: Configuration block lists both passwords (polarity: reject before state)
- **WHEN** the README `### Configuration` section is read
- **THEN** it lists `search.password` and `search.privilegedPassword` as required when `mode` is not `ingest`

### Requirement: Terraform operator requires both search passwords
The Terraform operator module SHALL define `variable "search"` with no default and a validation that rejects an empty `password` or an empty `root_password`; `index` and `user` therefore also become required. The values SHALL still flow to the generated GroundX config and to the OpenSearch release. `env.tfvars.example` and `env.tfvars.example-openshift` SHALL show placeholders for all four fields, with no colon in a placeholder.

#### Scenario: Missing search variable is rejected (polarity: reject before state)
- **WHEN** Terraform evaluates the `search` variable with no value supplied
- **THEN** evaluation fails because there is no default

#### Scenario: Empty password strings are rejected (polarity: reject before state; catches)
- **WHEN** `search.password` is an empty string, and separately when `search.root_password` is an empty string
- **THEN** variable validation fails in each case
- **AND** an empty string is not treated as "supplied"

#### Scenario: Supplied passwords are accepted (polarity: accept and enqueue; must not block)
- **WHEN** all four fields are non-empty
- **THEN** variable validation passes and the values reach `init/config/golang.tf` and `services/search/opensearch.tf`

### Requirement: Every render gate supplies test-only search passwords from one fixture
Every CI, gate, and declared render command that renders a non-ingest configuration SHALL supply test-only search passwords from a single literal-free fixture under `src/groundx/tests/files/`. Nothing SHALL be added to `values/minikube` or any install example to satisfy this. helm-unittest snapshots SHALL NOT depend on a chart default.

#### Scenario: Gate and declared commands use the fixture (polarity: reject before state)
- **WHEN** `.build/bin/validate-helm.sh` runs on the changed chart
- **THEN** it passes, and the workflow, `service.yaml`, `openspec/config.yaml` and `AGENTS.md` render commands reference the fixture

#### Scenario: Gate fails closed without the fixture (polarity: reject before state)
- **WHEN** a non-ingest render is attempted without search passwords
- **THEN** it fails naming the key, and is not silently satisfied by a default
