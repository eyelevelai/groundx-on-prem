## MODIFIED Requirements

### Requirement: `terraform/aws/`'s supported status is documented consistently
`README.md`, its linked `terraform/aws/README.md` and `docs/agents/repository-guide.md` SHALL describe `terraform/aws/`'s supported status consistently with
each other and with its actual, currently-deployed state on this branch: an optional path for
provisioning AWS infrastructure (a VPC and/or EKS cluster) ahead of the Helm install, and the
supported path for maintaining AWS infrastructure already provisioned through it. Neither document
may claim this path is retired, or scope it to existing deployments only — the November 4, 2025
migration retired the previous hybrid terraform-helm approach to deploying the *application* onto
the cluster (now a pure Helm release), not Terraform's role in provisioning or maintaining the
underlying AWS infrastructure.

#### Scenario: README and repository guidance agree on supported status
- **WHEN** `README.md`'s "Terraform Deployment (terraform/aws/)" section and `docs/agents/repository-guide.md`'s
  Terraform description are read together
- **THEN** both describe `terraform/aws/` the same way: optional for provisioning new AWS
  infrastructure and supported for maintaining existing AWS infrastructure it created — neither
  contradicts the other, neither claims retirement, and neither scopes the path to existing
  deployments only
