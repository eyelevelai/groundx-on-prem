# EKS DNS Incident Evidence

## Purpose

Preserve per-CoreDNS-pod metrics and extraction-worker DNS lookup evidence so operators can distinguish backend failures from worker network or service-path failures.

## Requirements

### Requirement: Opt-in CoreDNS collection preserves existing monitoring

The EKS Terraform SHALL retain explicit CloudWatch cost controls: Application Signals disabled and enhanced Container Insights enabled. When DNS observability is enabled, it SHALL keep the same main-agent configuration and add one dedicated CoreDNS collector that scrapes each CoreDNS pod and publishes metrics labelled by pod.

#### Scenario: Omitted setting

- **GIVEN** no DNS observability setting
- **WHEN** Terraform plans the EKS stack
- **THEN** the CloudWatch add-on has its explicit main-agent cost configuration and no CoreDNS collector

#### Scenario: Enabled setting

- **GIVEN** DNS observability is enabled
- **WHEN** Terraform plans the EKS stack
- **THEN** the existing agent retains its cost configuration and the additional collector is a single deployment with only CoreDNS scrape targets

### Requirement: Probe identifies the failing DNS path

The optional probe SHALL run in each extraction agent pod, resolve the configured Redis hostname with that pod's normal resolver, and on failure or slow resolution record kube-dns EndpointSlice readiness and direct query outcomes for every listed CoreDNS endpoint. Its Kubernetes permission SHALL be limited to listing EndpointSlices in `kube-system`.

#### Scenario: One ready endpoint stops answering

- **GIVEN** two ready CoreDNS endpoints, one responsive and one silent
- **WHEN** the normal resolution fails
- **THEN** the failure record shows both endpoints, their ready states, and the silent endpoint's timeout

#### Scenario: Normal resolution succeeds

- **GIVEN** the resolver returns an address
- **WHEN** the periodic probe runs
- **THEN** it records aggregate success without querying CoreDNS pods directly

### Requirement: Production rollout does not disrupt DNS

The rollout SHALL leave CoreDNS workload definitions unchanged, require review of the actual Terraform plan, and verify metric delivery. The sidecar rollout SHALL review the GroundX Helm change for unrelated resources, preserve in-flight extraction handling, account for per-pod resource requests, and verify both extraction pods and their probes before declaring evidence collection active. A failure injection SHALL run only in an authorized disposable cluster.

#### Scenario: Production activation

- **GIVEN** reviewed Terraform and Helm changes with no unrelated application changes
- **WHEN** evidence collection is activated
- **THEN** both CoreDNS pods publish metrics and both extraction pods produce probe logs
- **AND** no DNS failure is injected into production
