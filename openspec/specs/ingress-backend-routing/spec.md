# ingress-backend-routing Specification

## Purpose
TBD - created by archiving change gx-44-groundx-on-prem-five-ingresses-point-at-services-that-do-not. Update Purpose after archive.
## Requirements
### Requirement: Generated Ingress backend names the rendered `-api` Service
The chart SHALL name the generated (pathless) Ingress backend after the Service it actually creates (`groundx.<entry>.serviceName`, the `<component>-api` name) for each of the five API components — `extract.api`, `layout.api`, `ranker.api`, `summary.api`, `workspace.api` — on both supported Ingress API shapes, without changing the Ingress object's own `metadata.name`.

#### Scenario: `networking.k8s.io/v1` shape names the rendered Service — finalize success
- **WHEN** a pathless API Ingress (e.g. `workspace.api.ingress.enabled: true`) renders under the
  default `networking.k8s.io/v1` shape
- **THEN** `spec.rules[0].http.paths[0].backend.service.name` equals the entry's `-api` Service
  name (e.g. `workspace-api`), and is not equal to the Ingress object's own `metadata.name`

#### Scenario: legacy shape names the rendered Service — finalize success
- **WHEN** a pathless API Ingress sets `ingress.apiVersion: extensions/v1beta1`
- **THEN** `spec.rules[0].http.paths[0].backend.serviceName` equals the entry's `-api` Service name
  (e.g. `extract-api`), and is not equal to the Ingress object's own `metadata.name`

#### Scenario: Ingress object identity is unchanged — finalize success
- **WHEN** a pathless API Ingress renders, before and after the backend-name correction
- **THEN** `metadata.name` still equals the component's base `serviceName` (e.g. `workspace`), so
  `helm upgrade` patches the existing Ingress object rather than recreating it

### Requirement: A pathless API Ingress must not name a Service the chart does not create
The chart SHALL fail template rendering, for the five API components' pathless (generated) branch only, rather than render an Ingress whose backend Service the chart never creates; a custom `ingress.paths` block is user-managed and is out of scope for this requirement.

#### Scenario: catches — pathless ingress on a non-created component fails to render, reject before state
- **WHEN** a pathless API Ingress is enabled for a component that is not created (e.g.
  `extract.api.ingress.enabled: true` while `extract.api` is not created)
- **THEN** the template render fails with an error naming the entry and the reason, and no Ingress
  object is produced — the misconfiguration is rejected before any object exists

#### Scenario: must not block — a custom-paths ingress on a non-created component still renders, skip unrelated repair path
- **WHEN** an API Ingress sets a custom, non-empty `ingress.paths` block for a component that is
  not created
- **THEN** the template renders successfully with the user-supplied paths unchanged — the
  not-created-component guard is scoped to the pathless branch and does not fire here

