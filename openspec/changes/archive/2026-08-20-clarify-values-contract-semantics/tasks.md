## 1. Contract Tests

- [x] 1.1 Extend the production Helm gate to require deprecation metadata on both chart schemas.
- [x] 1.2 Add render-equivalence checks for `cluster.hasMig` and `cluster.tls.existingSecret` on both chart surfaces.
- [x] 1.3 Add static checks that reject the unused MIG helper and misleading TLS note paths.

## 2. Chart Cleanup

- [x] 2.1 Mark the compatibility fields deprecated and inert in `src/groundx/values.schema.json`.
- [x] 2.2 Remove the unused MIG helper and unsupported TLS note from `src/groundx`.
- [x] 2.3 Sync the matching schema and template changes into the `helm` publication mirror.

## 3. Validation And Rollout

- [x] 3.1 Run the production Helm gate, Helm lint, unit snapshots, and minikube render.
- [x] 3.2 Validate and archive the OpenSpec change into the base specification.
- [x] 3.3 Confirm the diff contains no workload, stateful-resource, Secret-content, or image change. Stage and production require no manual operation or secret rotation.
