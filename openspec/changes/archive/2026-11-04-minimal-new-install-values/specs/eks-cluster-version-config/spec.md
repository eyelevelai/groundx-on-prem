## MODIFIED Requirements

### Requirement: `terraform/aws/`'s supported status is documented consistently
`README.md` and `docs/agents/repository-guide.md` SHALL describe `terraform/aws/`'s supported status consistently with
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

### Requirement: AGENTS.md points hosted-production AWS changes at the production infra record
`AGENTS.md` SHALL link to `docs/agents/repository-guide.md` for repository rules. That guide SHALL carry one bullet under `## Agent boundaries`, directly after the `terraform/aws/` bullet, that tells a reader never to change GroundX hosted production AWS by hand, to record every change in `groundx-production-infra` in the same change (adding the resource if it is missing), and to apply through whatever currently manages the resource because adoption is partial. The bullet SHALL be scoped to GroundX hosted production only: it MUST NOT claim or imply that `terraform/aws/` is retired or limited, and MUST NOT contain a ticket id, internal link, account id, or ARN.

Polarity: skip unrelated repair path — the bullet adds a pointer only; the `terraform/aws/` bullet and the README section keep their current meaning.

#### Scenario: The pointer is present and scoped to hosted production
- **WHEN** the `## Agent boundaries` section of `docs/agents/repository-guide.md` is read
- **THEN** the bullet after the `terraform/aws/` bullet names `groundx-production-infra` and GroundX hosted production, and the `terraform/aws/` bullet still describes that path as optional for provisioning and supported for maintaining AWS infrastructure provisioned through it

#### Scenario: The pointer does not retire terraform/aws
- **WHEN** the new bullet and the `terraform/aws/` bullet are read together
- **THEN** nothing states or implies that `terraform/aws/` is retired, deprecated, or limited to existing deployments
