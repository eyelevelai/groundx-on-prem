## Implementation

- [x] Add default-off Terraform setting and one dedicated CoreDNS collector while preserving the default CloudWatch agent.
- [x] Add the separate extraction-node DNS probe chart and least-privilege EndpointSlice access.
- [x] Add focused local checks for default-off Terraform, CoreDNS scrape identity, normal and slow resolution, and a ready but silent DNS endpoint.
- [x] Document production plan review, activation, evidence query, and rollback.

## Rollout

- [x] Review the current production Terraform plan and install values. The plan updates only the CloudWatch add-on, with no create or destroy. Re-run against the state-owning checkout before apply.
- [ ] Obtain explicit approval for the production add-on update and probe install.
- [ ] Apply, verify collector metrics and probe logs, and monitor existing Container Insights and Application Signals.
- [ ] Run a live fault exercise only in an authorized disposable matching EKS cluster.
