## Context

The production AWS cluster is managed by the bundled `terraform/aws/eks` stack
even though the repository labels that path legacy. The stack already creates
managed node groups and installs `amazon-cloudwatch-observability` through its
`cluster_addons` map.

Recent CPU-node incidents left EC2 running and healthy while Kubernetes lost
the node. Existing CloudWatch evidence did not establish the final kernel,
networking, container-runtime, or memory state. AWS now provides these health
signals and native node log bundles through the EKS Node Monitoring Agent and
its `NodeDiagnostic` API.

The implementation must be one-switch, inert by default, simple to operate, and
must not make the cloud-neutral GroundX Helm chart depend on AWS.

## Goals / Non-Goals

**Goals:**

- One operator choice: `node_diagnostics.enabled`, default `false`.
- No diagnostic resources or behavioral changes while disabled.
- AWS-supported node conditions, events, and operator-triggered log bundles.
- Agent coverage on both configured CPU-only and CPU-memory worker pools.
- A short incident runbook using existing Kubernetes and AWS evidence paths.
- Existing Terraform ownership and naming patterns where they are sound.

**Non-Goals:**

- A custom incident collector, automatic capture, or a new evidence service.
- EKS node repair, node replacement, scaling, restart, cordon, or drain.
- Terraform-managed alarms, Lambda, EventBridge, SSM documents, lifecycle hooks,
  snapshots, Flow Logs, or evidence cleanup.
- Node launch-template, AMI, bootstrap, or journald changes.
- GroundX Helm, Prometheus, application, Celery, or workload-sizing changes.
- Applying Terraform or running a failure canary without separate authorization.

## Decisions

### 1. Use one typed, default-off Terraform input

Add the shared input and example value:

```hcl
node_diagnostics = {
  enabled = false
}
```

When omitted or false, the existing `cluster_addons` map remains unchanged. No
other diagnostic value is required from the operator.

### 2. Use the AWS-managed Node Monitoring Agent

Conditionally merge `eks-node-monitoring-agent` into the existing
`cluster_addons` map. Before implementation, identify the production Kubernetes
version, query the supported add-on versions and configuration schema, and pin
one exact compatible version that supports the `NodeDiagnostic` `node`
destination. AWS introduced that destination in `v1.6.1-eksbuild.1`; an older
version does not support the local-download path.

Configure the add-on's node-agent affinity from `local.cpu_only_label` and
`local.cpu_memory_label`, so it runs on both configured CPU pools and nowhere
else. Disable the add-on's NVIDIA monitor and use its supported scheduling
configuration to leave its DCGM component with no eligible nodes. The existing
CloudWatch Observability add-on remains the owner of GPU monitoring.

Production discovery on 2026-08-21 confirmed EKS 1.35 and add-on
`v1.7.0-eksbuild.1`. Its live AWS configuration schema supports `nodeAgent`
affinity and monitors plus `dcgmAgent.nodeSelector`. The implementation pins
that version.

Do not enable EKS node repair. The add-on publishes health conditions and events
only; remediation remains a separate decision.

Alternative considered: deploy a custom watcher or host collector. Rejected
because the AWS-managed add-on already owns node-health detection and bundle
collection.

### 3. Use `NodeDiagnostic` for normal evidence capture

Provide one small repo-owned operator command over the native `NodeDiagnostic`
API for one exact node and local download. This is a safe frontend to the AWS
collector, not another collector or service. It uses create-only semantics,
records the created resource UID, waits for and downloads the bundle, and
deletes with that UID as a precondition. Status and the downloaded output are
accepted only while that UID still owns the name. A concurrent or pre-existing
capture fails without being deleted, replaced, or overlapped. If another
resource later uses the same node name, the command fails, removes any partial
download, and leaves the replacement untouched.

The upstream `kubectl ekslogs` command deletes resources by node name, including
pre-existing resources. Do not invoke or copy that ownership behavior. Keep
batch capture and S3 upload logic out of the repo-owned command. The runbook may
link to AWS's manual S3 procedure for an approved bucket and retention policy;
this change does not create a bucket or execution role.

The bundle is treated as sensitive operational evidence. It is not committed,
attached to a ticket, or shared outside the approved incident path without
review.

Alternative considered: recreate the same collection with a Terraform-packaged
Lambda and SSM document. Rejected because it duplicates an AWS-supported path
and adds code, IAM, event delivery, retention, and failure modes.

### 4. Keep existing CloudWatch as supporting evidence

The current CloudWatch Observability add-on already owns Container Insights and
host, data-plane, and application log shipping. The implementation verifies the
actual enabled configuration and resulting log groups but does not replace or
extend that pipeline.

The incident runbook correlates the native bundle with Kubernetes node and pod
state, recent events, CloudWatch node metrics and logs, EC2 status, Auto Scaling
activity, and EC2 console output using UTC timestamps, node name, and instance
ID.

On a reachable node, verify that the native bundle contains the expected
kernel, memory, storage, container-runtime, and networking sources. If those
sources are absent, stop and revise the plan. Do not add a custom collector or
bootstrap change as an unreviewed fallback.

### 5. Make unreachable-node fallback explicit and manual

`NodeDiagnostic` requires enough node connectivity to collect or return the
bundle. When it cannot, the runbook preserves the incident identity and gathers
the remaining read-only Kubernetes and AWS evidence plus EC2 console output.

With separate authorization, the non-production canary removes EKS API
connectivity from a disposable CPU node while preserving CloudWatch and EC2
connectivity. It verifies that final host and data-plane logs, node conditions
and events, and EC2 and Auto Scaling timestamps remain available, and that the
native capture failure is clear. Stop and revise the plan if this evidence still
cannot explain the motivating node-disconnection event. Do not claim that this
single canary proves unrelated failure modes.

If offline disk evidence is still required, a root-volume snapshot is a
separate operator-approved action. This plan does not automatically delay
termination, create snapshots, or delete evidence. The known incident left the
instance running, so automatic termination interception is not justified yet.

### 6. Pin the applied EKS module before planning the change

The current `~> 20.0` constraint permits an unrelated module upgrade because
Terraform does not lock registry module versions in the provider lock file.
Determine the exact module version used by the production workspace and pin it
before reviewing the diagnostic diff. Stop if that version cannot be
established.

The production cluster was created after `20.37.2` became the final `20.x`
release. The repository wrapper runs `terraform init -upgrade`, and the current
constraint resolves to `20.37.2`. Pin that version and still require the
production plan to show no unrelated change.

## Risks / Trade-offs

- **CPU-pool add-on:** the managed agent runs on both configured CPU pools.
  Verify the pinned version's resources, tolerations, privileges, and absence
  from GPU pools while leaving existing CloudWatch GPU monitoring unchanged.
- **Native capture needs node connectivity:** use CloudWatch and EC2 console
  evidence when the node cannot return a bundle. Prove that path with an
  isolated disposable node. A snapshot remains an explicit incident operation,
  not background automation.
- **Sensitive bundles:** save locally by default and use existing access and
  retention controls for any separately approved manual upload.
- **Capture ownership:** create conflicts and UID-guarded cleanup are verified
  with focused command tests and a pre-existing-resource canary.
- **Legacy Terraform remains production authority:** keep the change optional
  and AWS-specific; do not make the Helm contract depend on it.

## Migration Plan

1. Fetch the remote and create the implementation branch from
   `origin/0.2.7`; record and verify the branch point.
2. Determine and pin the EKS module version used by production.
3. Determine the target Kubernetes version, pin a compatible Node Monitoring
   Agent version with `NodeDiagnostic` `node` destination support, and verify
   its supported CPU scheduling configuration.
4. Add the default-off input and conditional managed add-on, targeted to both
   configured CPU pools without changing existing GPU monitoring. Prove omitted
   and false plans are unchanged.
5. Add the exact-node, local-download operator command and runbook for atomic
   capture ownership and read-only AWS and Kubernetes correlation, with manual
   AWS S3 guidance and the separately approved snapshot fallback.
6. Review an enabled non-production plan. It must contain only the module pin,
   managed add-on, and documented input changes.
7. With separate authorization, canary the exact add-on and operator command.
   Verify create-conflict refusal, owned cleanup, node conditions, events,
   reachable bundle contents, CPU-pool scheduling, absence from GPU pools,
   resource use, disable behavior, and the focused fallback after removing a
   disposable CPU node's EKS API connectivity. Stop if the evidence is
   insufficient for the motivating disconnection.
8. Submit the verified implementation as a PR whose base branch is `0.2.7`.
9. Obtain separate production approval, review the production Terraform plan,
   and enable it without using the auto-approved `bin/environment` wrapper.
10. Review one natural incident before adding any automatic capture or repair.

Rollback sets `node_diagnostics.enabled` to `false` and applies a reviewed plan.
This removes the add-on without changing GroundX workloads or deleting bundles
saved outside Terraform.

## Open Questions

None. Cluster and add-on version discovery are rollout gates, not design choices.
