## ADDED Requirements

### Requirement: Credential-bearing config maps render as Kubernetes Secrets

The chart (`src/groundx/` and its `helm/` mirror alike) SHALL render every credential-bearing config resource as `kind: Secret`, not `kind: ConfigMap`: `config-yaml-map`, the per-service `*-config-py-map` (extract, ranker, summary, layout, workspace), and `layout-ocr-credentials-map`. Each SHALL keep its existing resource name and the mount path at which its consuming pod reads it, and the rendered file content (`config.yaml`, `config.py`, `credentials.json`) SHALL be byte-identical to the pre-conversion ConfigMap. Config resources that carry no credentials (`*-supervisord-conf`, `*-gunicorn-conf-py`, `config-models`, `ldconfig-symlink`) SHALL remain `kind: ConfigMap`. Pods that mount a converted resource SHALL reference it as a `secret:` volume (`secretName`), not a `configMap:` volume.

#### Scenario: Credential maps render as Secrets and pods mount them as secret volumes (polarity: finalize success)

- **GIVEN** the chart rendered with credential-bearing services enabled (the default services plus `extract` and `workspace`, and Google OCR configured with a packaged credentials file)
- **WHEN** `helm template` renders the chart (`src/groundx` and, independently, the `helm/` mirror)
- **THEN** `config-yaml-map`, each rendered `*-config-py-map`, and `layout-ocr-credentials-map` render as `kind: Secret` with `stringData`, keeping their names and file content
- **AND THEN** each pod mounting one of these references it as a `secret:` volume with the matching `secretName` (e.g. the golang deployment mounts `config-volume` from the `config-yaml-map` Secret), and none of these render as `kind: ConfigMap`

#### Scenario: Non-credential maps stay ConfigMaps (polarity: must-not-convert)

- **GIVEN** the same rendered chart
- **WHEN** `helm template` renders the config resources
- **THEN** `config-models-map`, the `*-supervisord-conf-map`s, the `*-gunicorn-conf-py-map`s, and `ldconfig-symlink-map` still render as `kind: ConfigMap`
- **AND THEN** the conversion has not widened beyond the credential-bearing resources (the opposite outcome — a non-credential map converted to a Secret — must not occur)
