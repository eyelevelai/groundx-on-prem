# GX-17: Render credential-bearing config maps as Secrets (chart-only)

- **Ticket**: GX-17
- **Author**: Nitin Vavdiya <nitin.vavdiya@smartsensesolutions.com>
- **Date**: 2026-08-27

## Why

Chart 0.2.7 renders workload credentials into plaintext `ConfigMap`s (not encrypted at rest by default): OpenSearch `search.*`, the summary OpenAI key, the application API keys, `file.password`, `mysql_password`, `runner_token`, and the Google OCR service-account JSON. GX-17 (remediating GX-18) requires these to use supported Kubernetes Secret paths.

## What

Render every credential-bearing config resource as `kind: Secret` instead of `ConfigMap`, **in place**: same resource name, same mount path, byte-identical file content. Because the workloads mount the same file regardless of source, there is no application change, no env-var contract, and no `values.schema.json` / `values.yaml` change.

Converted (both chart mirrors, `src/groundx/` and the `helm/` manual mirror):
- `templates/resources/config-yaml.yaml` — `config-yaml-map`
- `templates/resources/{extract,ranker,summary,layout,workspace}-config-py.yaml` — the per-service `*-config-py-map`
- `templates/resources/layout-ocr-credentials.yaml` — `layout-ocr-credentials-map`
- Pod templates (`templates/app/{golang,metrics,api,inference,celery}.yaml`) — the credential-map file volumes switch from `configMap:` to `secret:`.

Left as `ConfigMap` (no credentials): `*-supervisord-conf`, `*-gunicorn-conf-py`, `config-models`, `ldconfig-symlink`.

## Compatibility (not additive — a resource-kind replacement)

Not additive in the Kubernetes-resource sense: it replaces resource kinds (ConfigMap to Secret). Compatible at the values-API and app-behavior layers (no values change; apps read the identical mounted file). On upgrade, `apply` creates the same-named Secrets and deletes the ConfigMaps; the affected pods roll once via the existing `config-hash` annotation; `helm rollback` reverses it. Documented consumers that query these by kind (the on-prem harness: `kubectl get configmap config-yaml-map …`) break and are updated in the same 0.2.7 release under AGE-296.

## Out of scope

- `values.schema.json` / `values.yaml` changes (none needed).
- App-side changes (the superseded env-injection approach; see the cross-service plan in engineering-context, which supersedes the closed Option 1).
- Credential rotation (GX-18, operational) and the harness doc/scanner update (AGE-296).
