## MODIFIED Requirements

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

