## Why

AWS CPU nodes can be recreated with gp2 disks, and a Terraform add-on update can restore Application Signals collection after it has been disabled. The infrastructure definitions must retain the cost settings used by the deployment.

## What Changes

- Default only CPU-only root disks to gp3, 3000 IOPS, and 128 MiB/s, preserving size, encryption, and explicit operator disk overrides.
- Set the CPU-only node group update limit to one unavailable node.
- Explicitly disable Application Signals collection and auto-monitoring while keeping detailed Container Insights enabled.
- Retain the optional single CoreDNS collector and the existing add-on version selection.

## Capabilities

### New Capabilities

- `eks-cost-controls`: CPU disk defaults, CPU update limit, and CloudWatch cost configuration.

### Modified Capabilities

- `eks-dns-incident-evidence`: retain the explicit main-agent cost configuration when DNS collection is toggled.

## Impact

AWS Terraform inputs, generated EKS node-group/add-on configuration, plan tests, and operator documentation. Other node groups and Helm workloads remain unchanged. Applying CPU disk changes to an existing node group replaces its nodes and may briefly interrupt singleton workloads. No production apply is part of implementation.
