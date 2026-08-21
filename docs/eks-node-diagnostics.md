# EKS Node Diagnostics

This optional Terraform feature adds AWS's EKS Node Monitoring Agent to the
CPU-only and CPU-memory node groups. It does not change GroundX Helm workloads,
repair nodes, or run on GPU nodes. It is disabled by default.

## Enable

Set one value in `terraform/aws/env.tfvars`:

```hcl
node_diagnostics = {
  enabled = true
}
```

Review the Terraform plan before applying it. The diagnostic change should add
only `eks-node-monitoring-agent`; it must not replace or resize the cluster or
node groups. Do not use `bin/environment` for production enablement because it
applies automatically.

After apply, verify:

```bash
kubectl -n kube-system get daemonset eks-node-monitoring-agent
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-node-monitoring-agent -o wide
kubectl get nodes -L eyelevel_node
```

The node-agent pods must run only on nodes labelled
`eyelevel-cpu-only` or `eyelevel-cpu-memory`. The add-on's NVIDIA monitor is
disabled and its DCGM component has no eligible nodes, so the existing
CloudWatch GPU monitoring remains unchanged.

AWS lists node health monitoring as available
[at no additional cost](https://aws.amazon.com/about-aws/whats-new/2024/12/node-health-monitoring-auto-repair-amazon-eks/).
The agent still consumes CPU, memory, and temporary bundle disk on each selected
node; verify its actual footprint in the non-production canary before production.

## Capture one node

Requirements: `kubectl`, `jq`, access to the cluster, permission to create and
delete `NodeDiagnostic` resources, and permission to use the Kubernetes node
proxy.

Confirm the current context and exact node, then save the bundle in a protected
local directory:

```bash
kubectl config current-context
kubectl get nodes -L eyelevel_node
mkdir -m 700 node-evidence
bin/eks-node-logs --output-dir node-evidence NODE_NAME
```

The command refuses an existing capture. It creates one temporary
`NodeDiagnostic`, records its UID, downloads the bundle, and deletes only that
UID. An interrupted command attempts the same guarded cleanup. A replacement
with the same name is left untouched.

Bundles contain sensitive host and workload evidence. Do not commit them or
attach them to tickets without review. For an approved S3 destination, use
AWS's manual procedure:
https://docs.aws.amazon.com/eks/latest/userguide/auto-get-logs.html

## Correlate an incident

Record the UTC incident window, node name, instance ID, affected pod or task
IDs, and the saved bundle path. Collect these read-only surfaces for the same
window:

```bash
NODE=NODE_NAME
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | awk -F/ '{print $NF}')

kubectl get node "$NODE" -o yaml
kubectl get pods -A --field-selector "spec.nodeName=$NODE" -o wide
kubectl get events -A \
  --field-selector "involvedObject.kind=Node,involvedObject.name=$NODE" \
  --sort-by=.metadata.creationTimestamp

aws ec2 describe-instance-status --include-all-instances --instance-ids "$INSTANCE_ID"
aws autoscaling describe-auto-scaling-instances --instance-ids "$INSTANCE_ID"
aws ec2 get-console-output --latest --instance-id "$INSTANCE_ID"
```

In CloudWatch, query the cluster's `host`, `dataplane`, `performance`, and
`application` Container Insights log groups using the same UTC window, node
name, and instance ID. Also review the Auto Scaling group's activity history
for that window. Correlate the first abnormal host signal, the final kubelet
heartbeat, `NotReady`, pod eviction, task failure, and any replacement or
scale-up event.

## Unreachable node

Local capture needs enough node and Kubernetes connectivity to complete. If it
fails, keep the node and instance identifiers and use the Kubernetes,
CloudWatch, EC2, Auto Scaling, and console evidence above. Do not restart,
replace, drain, scale, or snapshot anything as part of collection. A root-volume
snapshot requires separate approval.

## Disable

Set `node_diagnostics.enabled = false` and apply a reviewed Terraform plan.
This removes the add-on. It does not delete bundles already saved outside
Terraform.
