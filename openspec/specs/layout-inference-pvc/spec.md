# layout-inference-pvc Specification

## Purpose
Document how the chart permits layout-inference PVC configuration so operators can use shared RWX model storage and scale layout inference across GPU nodes while preserving strict schema validation.
## Requirements
### Requirement: Schema permits `layout.inference.pvc`

`src/groundx/values.schema.json` and `helm/values.schema.json` SHALL define a `pvc` property under `layout.inference.properties`, as an object with properties `access`, `capacity`, `class`, `name` (all `type: string`) and `additionalProperties: false`, matching the shape already defined at `ranker.inference.properties.pvc`, and the two schema files SHALL remain byte-identical after the change.

**Contract polarity: accept and enqueue.** Today a values file that sets `layout.inference.pvc` is rejected by schema validation before the fix (this is the pre-change contract, not a bug to preserve). After this change the identical values file SHALL be accepted and SHALL render — the acceptance test must fail today (RED) for the file being rejected, and pass (GREEN) once the file is accepted, never the reverse.

#### Scenario: A values file setting `layout.inference.pvc` is accepted and renders

- **WHEN** a values file sets `layout.inference.pvc` with `access`, `capacity`, `class`, and `name`
- **THEN** `helm lint src/groundx` and `helm template src/groundx` succeed with no schema
  validation error
- **AND** the rendered `layout-inference` Deployment/PVC objects include the configured PVC
  volume and mount (per the existing `templates/_helpers/app/layout-inference.tpl` /
  `templates/app/inference.yaml` logic, which already supports this key)

#### Scenario: Schema newly accepts `pvc` but does not loosen `additionalProperties: false`

- **GIVEN** the fixed schema now permits `layout.inference.pvc`
- **WHEN** a values file sets an unrelated, still-unrecognized key directly under
  `layout.inference` (e.g. `layout.inference.bogusKey`)
- **THEN** schema validation still rejects that values file — `additionalProperties: false` on
  `layout.inference` continues to reject every key except the now-widened set that includes `pvc`
- **AND** this proves the fix is additive-and-narrow (permits exactly `pvc`, not a general
  loosening of the block)

### Requirement: `src/groundx/values.schema.json` and `helm/values.schema.json` stay byte-identical

Because `helm/` is a manual, unenforced mirror of `src/groundx/` (no regen script, no drift check), any edit to `src/groundx/values.schema.json` SHALL be mirrored verbatim into `helm/values.schema.json` in the same change.

#### Scenario: Byte-identity holds after the edit

- **WHEN** the `pvc` block is added to `layout.inference.properties` in
  `src/groundx/values.schema.json`
- **THEN** `helm/values.schema.json` is edited with the identical `pvc` block at the identical
  structural location
- **AND** `diff src/groundx/values.schema.json helm/values.schema.json` reports no differences
