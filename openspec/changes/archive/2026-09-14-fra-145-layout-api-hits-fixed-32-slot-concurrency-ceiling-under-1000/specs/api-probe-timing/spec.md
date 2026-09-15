## ADDED Requirements

### Requirement: API pods render an explicit probe timeoutSeconds

Each of the five API-pod Deployments (`layout`, `extract`, `ranker`, `summary`, `workspace`) SHALL
render a `timeoutSeconds` field on both its liveness probe and its readiness probe. Neither probe
SHALL rely on an implicit, unwritten value for this field.

Contract polarity: **finalize success** — the rendered manifest carries the field explicitly; the
opposite outcome (an omitted field that silently falls back to Kubernetes' built-in default) SHALL
NOT occur.

#### Scenario: Liveness probe carries an explicit timeout

- **GIVEN** the chart's default values, for each of the five API services
- **WHEN** that service's Deployment manifest is rendered
- **THEN** `spec.template.spec.containers[0].livenessProbe.timeoutSeconds` is present and equal to `3`
- **AND** the field is not absent from the rendered manifest

#### Scenario: Readiness probe carries an explicit timeout

- **GIVEN** the chart's default values, for each of the five API services
- **WHEN** that service's Deployment manifest is rendered
- **THEN** `spec.template.spec.containers[0].readinessProbe.timeoutSeconds` is present and equal to `3`
- **AND** the field is not absent from the rendered manifest

### Requirement: Readiness probe renders an explicit failureThreshold

Each of the five API-pod Deployments SHALL render a `failureThreshold` field on the readiness
probe. It SHALL NOT rely on Kubernetes' implicit default of `3` going forward — the value must be
written into the manifest, even though the shipped default reproduces that same number.

Contract polarity: **finalize success** — the field is present with the intended value; the
opposite outcome (the field silently absent, deriving its behavior from an unwritten Kubernetes
default) SHALL NOT occur.

#### Scenario: Readiness probe carries an explicit failureThreshold

- **GIVEN** the chart's default values, for each of the five API services
- **WHEN** that service's Deployment manifest is rendered
- **THEN** `spec.template.spec.containers[0].readinessProbe.failureThreshold` is present and equal to `3`
- **AND** the field is not absent from the rendered manifest

### Requirement: Default probe values preserve today's effective behavior

With no operator overrides, the rendered probe-timing values SHALL be: liveness `timeoutSeconds: 3`,
readiness `timeoutSeconds: 3`, readiness `failureThreshold: 3`. The liveness `failureThreshold`
SHALL remain `12`, unchanged by this change. The readiness `failureThreshold` default SHALL
reproduce Kubernetes' current implicit default (`3`) exactly, so no environment's readiness-ejection
behavior changes on this axis; only the two `timeoutSeconds` values change effective behavior
(widening the passing window, never narrowing it — see `design.md`).

Contract polarity: **finalize success** — the shipped defaults match the specified numbers exactly;
the opposite outcome (a default that silently drifts from the specified number, or a readiness
`failureThreshold` default other than `3`) SHALL NOT occur.

#### Scenario: No overrides present

- **GIVEN** an operator's values file that sets nothing under any service's `api.probe` block
- **WHEN** each of the five services' Deployment manifests is rendered
- **THEN** liveness `timeoutSeconds` is `3`, readiness `timeoutSeconds` is `3`, and readiness
  `failureThreshold` is `3` for every one of the five services
- **AND** liveness `failureThreshold` is unchanged at `12` for every one of the five services

### Requirement: Operators can override probe timing per service

An operator SHALL be able to override `timeoutSeconds` (liveness and readiness) and readiness
`failureThreshold` independently, through that service's own `api` values block, without those
overrides affecting any other of the five services.

Contract polarity: **finalize success** — an explicit override renders exactly as set; the
opposite outcome (the override being ignored and the chart default rendering instead, or the
override leaking into a sibling service's Deployment) SHALL NOT occur.

#### Scenario: An operator overrides one service's probe timing

- **GIVEN** an operator's values file that sets `layout.api.probe.liveness.timeoutSeconds: 7`,
  `layout.api.probe.readiness.timeoutSeconds: 9`, and
  `layout.api.probe.readiness.failureThreshold: 5`
- **WHEN** the `layout-api` Deployment manifest is rendered
- **THEN** its liveness `timeoutSeconds` is `7`, its readiness `timeoutSeconds` is `9`, and its
  readiness `failureThreshold` is `5`
- **AND** the `ranker-api`, `summary-api`, `extract-api`, and `workspace-api` Deployments in the
  same render still carry the unmodified chart defaults (`3`, `3`, `3`)

### Requirement: The values schema rejects undeclared or malformed probe-timing keys

For all five services' `*.api` blocks, the values schema SHALL reject an undeclared key nested
under `api.probe`, `api.probe.liveness`, or `api.probe.readiness`, and SHALL reject a
non-integer value for any of `liveness.timeoutSeconds`, `readiness.timeoutSeconds`, or
`readiness.failureThreshold`. Rejection SHALL happen at Helm's values-schema validation step,
before any template renders and before any manifest is produced.

Contract polarity: **reject before state** — an invalid or undeclared probe-timing key SHALL
cause `helm template`/`helm install`/`helm upgrade` to fail closed with no manifest emitted for
any of the five services; the opposite outcome (the key being silently ignored and a manifest
still rendering) SHALL NOT occur.

#### Scenario: An undeclared probe-timing key is rejected, for each of the five services

- **GIVEN** an operator's values file that sets an undeclared key under that service's
  `api.probe` block (for example `api.probe.liveness.retries`)
- **WHEN** `helm template` runs
- **THEN** validation fails and no manifest is rendered for that service or any other
- **AND** no partial or default-substituted manifest is produced in place of the rejected input

#### Scenario: A malformed probe-timing value is rejected, for each of the five services

- **GIVEN** an operator's values file that sets a non-integer value on that service's
  `api.probe.readiness.timeoutSeconds` (for example a string)
- **WHEN** `helm template` runs
- **THEN** validation fails and no manifest is rendered for that service or any other

### Requirement: The `helm/` mirror renders identically to `src/groundx` for these fields

The manually-synced `helm/` mirror SHALL render the same liveness/readiness `timeoutSeconds` and
readiness `failureThreshold` values as `src/groundx`, for every one of the five services, under
both chart defaults and an operator override.

Contract polarity: **finalize success** — the two chart trees agree on the rendered value; the
opposite outcome (a value that renders differently between `src/groundx` and `helm/`, silently
reintroducing the drift this repo already flags as a known gap) SHALL NOT occur.

#### Scenario: Both chart trees agree under defaults

- **GIVEN** the chart's default values
- **WHEN** each of the five services' Deployment manifests is rendered from `src/groundx` and
  separately from `helm/`
- **THEN** the two renders carry identical liveness `timeoutSeconds`, readiness `timeoutSeconds`,
  and readiness `failureThreshold` values for every service

#### Scenario: Both chart trees agree under an operator override

- **GIVEN** an operator's values file that sets a non-default `timeoutSeconds` (liveness and
  readiness) and readiness `failureThreshold` on every one of the five services' `api.probe`
  blocks
- **WHEN** each of the five services' Deployment manifests is rendered from `src/groundx` and
  separately from `helm/`
- **THEN** the two renders carry identical liveness `timeoutSeconds`, readiness `timeoutSeconds`,
  and readiness `failureThreshold` values for every service, matching the operator's override
- **AND** neither tree silently falls back to the chart default in place of the override

#### Scenario: catches — a mirror render that diverges on a probe field, or resolves to no value, is rejected

- **GIVEN** two renders of the same service being compared for probe-timing drift, where either
  render's liveness `timeoutSeconds`, readiness `timeoutSeconds`, or readiness `failureThreshold`
  differs from the other, or where either render has no Deployment by that service's name, or is
  missing one of those three fields on the Deployment it does have
- **WHEN** the probe-mirror-drift guard compares the two renders
- **THEN** the guard reports drift and fails
- **AND** an unresolved value (the Deployment absent, or the field absent) is treated as drift, not
  silently treated as agreeing with the other render

#### Scenario: must not block — a mirror render that differs only in a non-probe field is accepted

- **GIVEN** two renders of the same service whose liveness `timeoutSeconds`, readiness
  `timeoutSeconds`, and readiness `failureThreshold` are identical, but which differ in an
  unrelated field (for example, container image tag)
- **WHEN** the probe-mirror-drift guard compares the two renders
- **THEN** the guard reports no drift and passes

### Requirement: Probe-timing changes do not alter the `/health` contract during a mixed rollout

Changing probe timing SHALL NOT change the path, method, or expected response of the `GET /health`
call the probes make. An API pod running the old (unmodified) probe timing and one running the new
timing SHALL both continue to interoperate correctly with either version of the paired `ai-server`
`/health` handler, since the touchpoint itself (path, method, 200-shape) is unchanged by this
change on either side.

Contract polarity: **finalize success**, with a backward-compatibility scenario for the two
same-level, either-may-ship-first changes named in `proposal.md`.

#### Scenario: Old probe timing continues to work against either ai-server version

- **GIVEN** an API pod deployed with this chart's new probe-timing defaults
- **WHEN** its liveness and readiness probes call `GET /health` on the paired `ai-server` image,
  whether or not that image has picked up the paired FRA-145 `ai-server` fix
- **THEN** the probe still targets the same path (`/health`), the same method (`GET`), and the
  same port as before this change
- **AND** rollout order between this change and the paired `ai-server` change does not affect
  which one is safe to deploy first
