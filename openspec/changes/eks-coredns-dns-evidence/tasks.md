## Implementation

- [x] Add default-off Terraform setting and one dedicated CoreDNS collector while preserving the default CloudWatch agent.
- [x] Add the extraction-pod DNS probe sidecar and least-privilege EndpointSlice access.
- [x] Add focused local checks for default-off Terraform, CoreDNS scrape identity, normal and slow resolution, and a ready but silent DNS endpoint.
- [x] Run the Terraform and Python probe checks in the existing Helm CI job, sharing setup and the existing Helm validation gate.
- [x] Document production plan review, activation, evidence query, and rollback.

## Rollout

- [x] Review the current production Terraform plan and install values. The plan updates only the CloudWatch add-on, with no create or destroy. Re-run against the state-owning checkout before apply.
- [x] Apply the production add-on update, verify both CoreDNS pods publish metrics, and monitor existing Container Insights and Application Signals.
- [x] Review the full production Helm change, worker task handling, and resource headroom before rolling extraction pods.
- [x] Roll out the sidecar and verify logs from both ready extraction pods on separate CPU nodes.

## Future validation

A live fault exercise requires an authorized disposable matching EKS cluster. None is currently reachable. The local test covers one ready DNS endpoint that answers and one that times out.
