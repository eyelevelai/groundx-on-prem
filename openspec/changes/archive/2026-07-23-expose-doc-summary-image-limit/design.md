# Expose Document Summary Image Limit Design

## Goals

- Let on-prem operators configure the document-summary page image limit through
  values.
- Render the value into the app's `config.yaml` under the existing `engines`
  block.
- Keep the chart change small and isolated to config rendering.
- Preserve strict schema validation.

## Non-Goals

- No app runtime changes in this repo.
- No new pod, service, queue, secret, or stateful resource.
- No model server tuning.
- No chart publish operation.

## Source Evidence To Re-Read Before Implementation

- `AGENTS.md`
- `openspec/config.yaml`
- `src/groundx/values.yaml`
- `src/groundx/values.schema.json`
- `src/groundx/templates/_helpers/engines.tpl`
- `src/groundx/templates/resources/config-yaml.yaml`
- matching files under `helm/` for manual mirror sync
- GroundX Studio Harness on-prem `values-yaml.md`
- `cashbot-go` OpenSpec change `limit-doc-summary-page-images`

## Proposed Values Surface

Add:

```yaml
engines:
  default:
    maxImages: 30
```

The field means: maximum page image attachments the `cashbot-go` runtime should
send in one document-summary request when using this engine config.

This chart does not enforce request behavior. It only renders config.

## Rendered Config

When `engines.default.maxImages` exists, render:

```yaml
engines:
  default:
    maxImages: 30
```

in the application `config.yaml` engine entry.

When operators provide a positive integer `maxImages`, preserve and render their
supplied value. When operators omit `maxImages` or explicitly set it to `null`,
do not render the field; the app runtime default of 30 remains the source of
default behavior. Reject non-positive and non-integer values during Helm schema
validation.

## Rollout

1. Merge and deploy the `cashbot-go` app change first or in the same release
   train.
2. Merge the chart config exposure.
3. Upgrade a non-production self-hosted environment and confirm rendered
   `config.yaml` includes `engines.default.maxImages` when the value is set.
4. Confirm the running app image consumes the field before claiming the provider
   image-limit issue is fixed.
5. Promote to production/self-hosted customer environments.

## Rollback

The field is config-only. Removing it or rolling back the chart returns the app
to its built-in default once the runtime change exists. No data migration or
stateful rollback is needed.

## Validation

- `helm lint src/groundx`
- `helm template src/groundx -f src/groundx/values/minikube/values.yaml`
- `helm unittest src/groundx`
- `OPENSPEC_TELEMETRY=0 npx --yes @fission-ai/openspec@1.3.1 validate --all --strict --json`
- `git diff --check`
- source/mirror diff review for `src/groundx` and `helm/`

If `helm-unittest` snapshots change, regenerate them with `helm unittest -u
src/groundx`; do not edit snapshots by hand.
