# EKS DNS Incident Evidence

## Requirements

### Requirement: Opt-in CoreDNS collection preserves existing monitoring

The EKS Terraform SHALL leave the CloudWatch add-on unchanged by default. When DNS observability is enabled, it SHALL retain the default `cloudwatch-agent` and add one dedicated CoreDNS collector that scrapes each CoreDNS pod and publishes metrics labelled by pod.

#### Scenario: Omitted setting

- **GIVEN** no DNS observability setting
- **WHEN** Terraform plans the EKS stack
- **THEN** the CloudWatch add-on has no custom configuration

#### Scenario: Enabled setting

- **GIVEN** DNS observability is enabled
- **WHEN** Terraform plans the EKS stack
- **THEN** the existing agent has no overrides and the additional collector is a single deployment with only CoreDNS scrape targets

### Requirement: Probe identifies the failing DNS path

The probe SHALL run on extraction CPU nodes, resolve the configured Redis hostname with the normal pod resolver, and on failure or slow resolution record kube-dns EndpointSlice readiness and direct query outcomes for every listed CoreDNS endpoint. Its Kubernetes permission SHALL be limited to reading EndpointSlices in `kube-system`.

#### Scenario: One ready endpoint stops answering

- **GIVEN** two ready CoreDNS endpoints, one responsive and one silent
- **WHEN** the normal resolution fails
- **THEN** the failure record shows both endpoints, their ready states, and the silent endpoint's timeout

#### Scenario: Normal resolution succeeds

- **GIVEN** the resolver returns an address
- **WHEN** the periodic probe runs
- **THEN** it records aggregate success without querying CoreDNS pods directly

### Requirement: Production rollout does not disrupt DNS

The rollout SHALL leave GroundX and CoreDNS workload definitions unchanged, require review of the actual Terraform plan, and verify metric delivery and probe placement before declaring evidence collection active. A failure injection SHALL run only in an authorized disposable cluster.
