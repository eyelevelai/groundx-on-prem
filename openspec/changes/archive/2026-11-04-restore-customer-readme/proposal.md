## Why

The main README is the customer-facing product introduction and quick start. Later additions have mixed that purpose with optional-feature configuration, implementation details and upgrade runbooks. Restore the earlier editorial structure and reuse its language while keeping current, useful information available.

The baseline is `aecde7bc63029f936f85051de023c0aa10a9a798:README.md` (February 19, 2026). Its content matches the README immediately before `AGENTS.md` entered the release ancestry through merge `41705c044f70911d24bb770f583196cca47d3c32` on June 22, 2026. This is a verifiable history boundary, not an inference about the authorship of every later edit.

## What Changes

- Reuse the baseline's headings, order, explanations, images and short instructions wherever still accurate.
- Update obsolete settings, commands, prerequisites and safety statements against current source. Retain the current minimal starter and existing-customer upgrade protections.
- Preserve later useful information in the README or the most appropriate existing guide. Create a small topic guide only where there is no suitable home.
- Serve humans and agents from the same technical information. Keep agent contribution rules in linked agent guidance and `AGENTS.md` as an index.
- Add reciprocal written guidance for checking affected Harness on-prem references when documentation or behavior changes. Reuse current validation and packaging commands.
- Add no synchronization automation, new scanners, cross-repo CI, generated documentation, mandatory companion-PR gate or new documentation framework.

## Capabilities

### New Capabilities

- `customer-readme`: baseline-led customer documentation, preservation of useful detail and simple maintenance guidance for both audiences.

### Modified Capabilities

- `s4-storage-type`: align documentation locations while preserving deployment and safety requirements.
- `existing-redis-tls-upgrade-guidance`: align documentation locations while preserving deployment and safety requirements.
- `summary-inference-gpu-sizing`: align documentation locations while preserving deployment and safety requirements.
- `eks-cluster-version-config`: align documentation locations while preserving deployment and safety requirements.
- `object-store-install-and-upgrade`: align documentation locations while preserving deployment and safety requirements.

## Impact

Documentation and necessary reference-location updates in `groundx-on-prem`, plus affected source references and maintenance guidance in `groundx-studio-harness`. No chart values, templates, schemas, application behavior, images, customer data, infrastructure, dev/staging/prod deployment or live acceptance state changes. Documentation rollback restores the prior files; it requires no database or infrastructure rollback.

This is a proposed plan. Implementation tasks remain unchecked. Open design questions: none.
