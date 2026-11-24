# database-upgrade-gate Specification

## Purpose
Run database migrations before Helm replaces Go workloads, preserving existing application resources when migration fails.
## Requirements
### Requirement: Database upgrade precedes application replacement
The chart SHALL run the target GroundX migration command before upgrading Go workloads.

#### Scenario: Upgrade with API or workers
- **GIVEN** at least one Go workload is enabled
- **WHEN** Helm upgrades the release
- **THEN** the target-config Secret and migration Job run before application replacement

#### Scenario: Failed migration
- **GIVEN** the migration Job fails
- **WHEN** Helm processes the pre-upgrade hook
- **THEN** regular resources are not upgraded and failed hook diagnostics remain available

### Requirement: Fresh installs and isolated services remain supported
The chart SHALL preserve fresh-install ordering and avoid creating migration work for deployments without Go workloads.

#### Scenario: Fresh database
- **GIVEN** a new installation with chart-managed database
- **WHEN** Helm installs the release
- **THEN** no pre-install migration hook blocks backing-service creation

#### Scenario: Worker-only upgrade
- **GIVEN** GroundX API is disabled and a Go ingestion worker is enabled
- **WHEN** Helm upgrades the release
- **THEN** the migration hook still protects that worker

### Requirement: Migration uses the target deployment configuration
The migration Job SHALL use the GroundX image and database configuration without depending on search, Redis, queues or workspace services.

#### Scenario: Image and security overrides
- **GIVEN** custom image, service account, security, scheduling and credential references
- **WHEN** the upgrade Job renders
- **THEN** the relevant GroundX settings are preserved, its configuration is isolated from running pods, and its labels cannot select it as an API endpoint

### Requirement: Migration Job deadline and retry count are chart values
The migration Job SHALL take `spec.activeDeadlineSeconds` from `groundx.migration.activeDeadlineSeconds` and `spec.backoffLimit` from `groundx.migration.backoffLimit`. The defaults SHALL be 3600 and 2. An explicit `backoffLimit: 0` SHALL render as 0 and MUST NOT be replaced by the default. `src/groundx` and the `helm/` mirror SHALL render the same values. A values file that sets no `groundx.migration` key SHALL render the same migration Job as before except for these two numbers. `bash .build/bin/validate-helm.sh` checks this for both chart copies, and the `golang_test.yaml` helm-unittest suite checks it for `src/groundx`.

#### Scenario: Defaults raise the deadline and add retries [finalize success]
- **GIVEN** a values file that sets no `groundx.migration` key and enables at least one Go workload
- **WHEN** the chart renders with `--is-upgrade`
- **THEN** the migration Job has `activeDeadlineSeconds: 3600` and `backoffLimit: 2`
- **AND** it does not have the old `activeDeadlineSeconds: 900` or `backoffLimit: 0`

#### Scenario: Set values render as given and an explicit zero retry count survives [finalize success]
- **GIVEN** `groundx.migration.activeDeadlineSeconds: 7200` and `groundx.migration.backoffLimit: 0`
- **WHEN** the chart renders with `--is-upgrade`
- **THEN** the migration Job has `activeDeadlineSeconds: 7200` and `backoffLimit: 0`

#### Scenario: Gate catches a template that turns an explicit zero into the default
- **GIVEN** a template that reads `backoffLimit` with `| default 2`, so an explicit 0 renders as 2
- **WHEN** `bash .build/bin/validate-helm.sh` or the `golang_test.yaml` suite runs
- **THEN** it fails on the case that sets `backoffLimit: 0`

#### Scenario: Existing values files keep the same migration Job apart from the two limits [backward compatibility]
- **GIVEN** the five committed `golang_test.yaml` migration Job snapshot fixtures, none of which sets a `groundx.migration` key
- **WHEN** the snapshot is regenerated with this change
- **THEN** each of the five Job documents differs from the base snapshot only in `activeDeadlineSeconds` (900 to 3600) and `backoffLimit` (0 to 2)
- **AND** no other snapshot entry changes when the files are compared as parsed YAML

#### Scenario: Both chart copies render the same limits
- **GIVEN** the default values and the 7200/0 values above
- **WHEN** `bash .build/bin/validate-helm.sh` renders `src/groundx` and `helm/`
- **THEN** both copies render the same deadline and retry count for each input

### Requirement: The values schema rejects a deadline below 1 and a negative retry count
Both `values.schema.json` files SHALL define `groundx.migration` as an object with `activeDeadlineSeconds` (integer, minimum 1), `backoffLimit` (integer, minimum 0) and `gitOps` (boolean), and `additionalProperties: false`. A render with an out-of-range value SHALL fail before any manifest is produced, and the error SHALL be the `minimum` error for that key, not the unknown-key error.

#### Scenario: Zero deadline is rejected by its minimum [reject before state]
- **GIVEN** `groundx.migration.activeDeadlineSeconds: 0`
- **WHEN** `helm template` renders either chart copy
- **THEN** the render fails with `at '/groundx/migration/activeDeadlineSeconds': minimum: got 0, want 1`
- **AND** no manifest is written

#### Scenario: Negative retry count is rejected by its minimum [reject before state]
- **GIVEN** `groundx.migration.backoffLimit: -1`
- **WHEN** `helm template` renders either chart copy
- **THEN** the render fails with `at '/groundx/migration/backoffLimit': minimum: got -1, want 0`
- **AND** no manifest is written

#### Scenario: Gate catches a rejection for the wrong reason
- **GIVEN** a schema with no `groundx.migration` property, which rejects any `groundx.migration` key as an unknown property
- **WHEN** `bash .build/bin/validate-helm.sh` runs
- **THEN** it fails, because the valid 7200/0 render fails and the rejection text does not name the `minimum` check

#### Scenario: Valid limits are not blocked [must not block]
- **GIVEN** `groundx.migration.activeDeadlineSeconds: 7200` and `groundx.migration.backoffLimit: 0`, or no `groundx.migration` key
- **WHEN** `bash .build/bin/validate-helm.sh` renders both chart copies
- **THEN** the renders succeed and the gate passes these cases

### Requirement: An opt-in renders the migration hooks without an upgrade flag
When `groundx.migration.gitOps` is true, the chart SHALL render the migration Secret and Job even when `.Release.IsUpgrade` is false, as long as at least one Go workload is enabled. The hook annotations SHALL stay as they are: `helm.sh/hook: pre-upgrade`, weight `-10` for the Secret and `-5` for the Job, and delete policy `before-hook-creation,hook-succeeded`. The default SHALL be false, and with it false the chart SHALL render exactly as it does without this change.

#### Scenario: Opt-in render without an upgrade includes both hooks [accept and enqueue]
- **GIVEN** `groundx.migration.gitOps: true` and at least one Go workload enabled
- **WHEN** the chart renders without `--is-upgrade`
- **THEN** the render contains the migration Secret and the migration Job
- **AND** both carry `helm.sh/hook: pre-upgrade`

#### Scenario: Default render without an upgrade includes neither hook [must not block]
- **GIVEN** `groundx.migration.gitOps` is unset or false
- **WHEN** the chart renders without `--is-upgrade`
- **THEN** the render contains neither the migration Secret nor the migration Job

#### Scenario: Opt-in without Go workloads renders no hook [skip unrelated repair path]
- **GIVEN** `groundx.migration.gitOps: true` and every Go workload disabled
- **WHEN** the chart renders without `--is-upgrade`
- **THEN** the render contains no migration Secret or Job

#### Scenario: Argo CD runs the migration before updating Deployments [finalize success]
- **GIVEN** an existing release on minikube with an external MySQL, managed by an Argo CD Application with `groundx.migration.gitOps: true`
- **AND** the migration lock is held by another MySQL session for more than 30 seconds when the sync starts, so the first Job pod fails
- **WHEN** Argo CD syncs a chart change that rolls the Deployments
- **THEN** the migration Job finishes with at least one failed pod and one succeeded pod before any ReplicaSet created by that sync exists
- **AND** the migration Secret exists when each Job pod starts, and each pod mounts it by name
- **AND** the recorded result names the Argo CD version

#### Scenario: Argo CD with the opt-in off creates no migration Job [must not block]
- **GIVEN** the same Application with `groundx.migration.gitOps` unset
- **WHEN** Argo CD syncs
- **THEN** no migration Job is created

### Requirement: The upgrade guide covers the new limits, timing and the opt-in
`docs/agents/database-upgrades.md` SHALL tell operators how to time the migration, size Helm's `--timeout`, how retries and the migration lock interact, what to check after a Helm timeout, and what the opt-in needs. It SHALL NOT state the old 15-minute deadline, say there is no automatic retry, or suggest `--timeout 20m`. It SHALL NOT promise that a retried history build resumes, since that depends on the GroundX image.

#### Scenario: Guide states each required item
- **WHEN** an operator reads `docs/agents/database-upgrades.md`
- **THEN** it says to time `-migrate-only` on a restored snapshot first and that row count is context only
- **AND** it says to set `--timeout` above the Job deadline plus the rollout, with `--timeout 70m` as the example
- **AND** it says retries share the deadline and that each attempt fails if another process holds the migration lock for more than 30 seconds
- **AND** it says to check whether `<release>-schema-migration` is still running after a Helm timeout before running the upgrade again
- **AND** it says the opt-in needs the database, credentials, service account and image pull Secrets before PreSync and is not for a first sync with the bundled MySQL

#### Scenario: Old limits are gone from the guide
- **WHEN** `docs/agents/database-upgrades.md` is searched
- **THEN** it does not contain `15-minute deadline`, `no automatic retry` or `--timeout 20m`

