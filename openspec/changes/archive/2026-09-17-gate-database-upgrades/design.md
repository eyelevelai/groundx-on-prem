## Design

Use the existing GroundX image entrypoint `/app/bootstrap` with `-migrate-only`, supplied by Cashbot's `gate-database-upgrades` change. Only render hooks for upgrade operations with at least one Go workload. Use a dedicated release-scoped Secret containing the regular config template's stringData, at weight -10, then a Job at weight -5. Do not reuse or overwrite the running configuration Secret.

The Job uses GroundX image, scheduling, service account, security, resources and image-pull settings. Global environment Secrets remain available. Workspace-token environment bindings and unrelated dependency wait containers are absent. Hook pod labels must not match application Service selectors. Existing external credentials/service accounts and target DB endpoints must be available before upgrade.

No pre-install hook is used: chart-managed backing services do not exist then. Normal GroundX startup performs initialization; each compatible Go worker checks its actual required reader and writer schema before queue consumption. Worker-only upgrades also run the GroundX migration image even if the API is disabled. Installations with no Go workloads have no migration job.

The Job permits no automatic retry, has a 15-minute deadline, retains failed resources for diagnosis and removes successful hooks. The operator must allow sufficient Helm timeout for migration plus rollout. A subsequent attempt replaces previous hook resources and safely resumes additive SQL. Application rollback leaves database additions intact.

## Validation

Extend existing golang/resource suites and fixtures, with upgrade snapshots for default, external DB, OpenShift, minikube, metadata and disabled settings. Assert CLI, hook order, target config, image override, non-application labels, global Secrets, security, disabled API with enabled worker, all disabled and fresh install. Run the existing full dual-surface gate. Manifests and disposable database tests are not proof of FraudX recovery; no customer access is available.

## Delivery

Merge/build Cashbot first, then the dependent 0.2.7 chart. Deploy only after separately approved exact engine/schema validation and image selection. The existing archived large-file-delivery plan's schema-before-workers rule remains unchanged. This adds enforcement, not extraction or queue protocol changes.
