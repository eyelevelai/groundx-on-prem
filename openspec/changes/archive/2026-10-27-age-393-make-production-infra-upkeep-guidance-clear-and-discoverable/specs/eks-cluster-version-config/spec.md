## ADDED Requirements

### Requirement: AGENTS.md points hosted-production AWS changes at the production infra record
`AGENTS.md` SHALL carry one bullet under `## Agent boundaries`, directly after the `terraform/aws/` bullet, that tells a reader never to change GroundX hosted production AWS by hand, to record every change in `groundx-production-infra` in the same change (adding the resource if it is missing), and to apply through whatever currently manages the resource because adoption is partial. The bullet SHALL be scoped to GroundX hosted production only: it MUST NOT claim or imply that `terraform/aws/` is retired or limited, and MUST NOT contain a ticket id, internal link, account id, or ARN.

Polarity: skip unrelated repair path — the bullet adds a pointer only; the `terraform/aws/` bullet and the README section keep their current meaning.

#### Scenario: The pointer is present and scoped to hosted production
- **WHEN** the `## Agent boundaries` section of `AGENTS.md` is read
- **THEN** the bullet after the `terraform/aws/` bullet names `groundx-production-infra` and GroundX hosted production, and the `terraform/aws/` bullet still describes that path as optional for provisioning and supported for maintaining AWS infrastructure provisioned through it

#### Scenario: The pointer does not retire terraform/aws
- **WHEN** the new bullet and the `terraform/aws/` bullet are read together
- **THEN** nothing states or implies that `terraform/aws/` is retired, deprecated, or limited to existing deployments
