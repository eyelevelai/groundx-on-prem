## Design

Change only `nodes.node_groups.cpu_only_nodes.ebs` defaults in `terraform/aws/variables.tf`; retain the existing input-to-launch-template mapping so explicit disk overrides keep working. Set `update_config.max_unavailable = 1` on the CPU-only group instead of changing the shared EKS defaults.

Always emit the CloudWatch add-on configuration. Its manager disables both `monitorAllServices` and `restartPods`. The Linux main agent explicitly collects Kubernetes metrics with enhanced Container Insights, without Application Signals log or trace collectors. Append the existing CoreDNS collector only when `dns_observability.enabled` is true, preserving its scraper, metrics, labels, and version pin.

## Validation

Mock-provider Terraform plans check the CPU disk settings and one-node update limit, untouched disk defaults in other pools, explicit CloudWatch defaults with DNS off, and main-agent/collector behavior with DNS on. Validate the emitted configuration against the installed AWS add-on schema and compare the DNS-enabled JSON with current production configuration through read-only queries. Run the repository production gate and a Helm render.

Application images, extraction schemas, task chains, and prompt policies are unchanged, so Arcadia legacy, Arcadia v1, generic v1, and ADP v1 fixture outputs are not affected by this source change. Any later live node rollout still needs ingress, extraction, search, and Studio verification.

## Rollout

Use the existing production Terraform state and current input files. Review a saved plan before applying. Stop on cluster replacement/version changes, other node-group rollouts, or stateful-service changes. This PR does not import or select a manually created template version; Terraform must reconcile its managed template through the reviewed plan. Wait for active document and workspace work to finish. Use a normal EKS update, without forced eviction. Singleton services may pause during relocation; temporary replacement capacity is charged normally.

## Recovery

Do not force a blocked drain. Correct readiness or workload completion before retrying. Reverting the source and applying another reviewed plan can itself cause node replacement and can re-enable paid telemetry; rollback is not an instantaneous restart-free operation.
