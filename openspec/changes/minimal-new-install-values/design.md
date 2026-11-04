## Design

Use the existing README workflow: copy `sample.values.yaml`, customize it, and pass that same file to `helm install` and subsequent upgrades. Keep the chart-wide default off. Automatic install detection and saved-state migration are unnecessary because the sample is an explicit customer values file.

The starter targets the existing full-deployment path with separately installed backing-service prerequisites. Preserve database application/migration credentials and search application/administrator credentials, but use replacement placeholders. Preserve `admin.email`, API key and username; omit `admin.password`, which does not establish a default or local-mode password. Point to the identity guide for login choices.

The object-store block sets its bucket and stable file-delivery hostname. The file-access block enables the existing gateway and names HTTPS storage/signing endpoints, an existing storage credentials Secret and gateway ingress/TLS settings. Leave both verification assertions false until the operator verifies the selected backend and transport. Do not manufacture proof from a TLS Secret or make existing buckets private automatically.

Extend `resources_test.yaml` using the real root sample as the values input. With filled synthetic license/admin values and verified transport assertions, check the rendered license, gateway configuration and private storage endpoints. Separately require unverified origins and unverified TLS to fail before installation. Existing suites continue to protect default/legacy renders and extraction configuration; no extraction runtime, workflow, task-chain or prompt change affects Arcadia legacy, Arcadia v1, generic v1 or ADP v1.

No new production code or Kubernetes resource is introduced. The sample and README are not mirrored chart sources. The identity specification's starter-file requirement is revised to match the smaller sample; the full provider field definitions stay documented in the identity guide and schema.

## Validation

Run the focused resource suite before and after the sample edit, then the complete `.build/bin/validate-helm.sh` gate with Helm 3.19.0 and the pinned helm-unittest binary. Render both source and published charts using the completed sample, compare their output, and verify their packaged defaults and templates have no diff. No cluster or database operation is required.
