## Design

Each existing PodDisruptionBudget block retains `minAvailable: 1` and its service selector. Render `unhealthyPodEvictionPolicy: AlwaysAllow` only when `semverCompare ">=1.26-0" $.Capabilities.KubeVersion.Version` is true. This uses the Helm target cluster version and also accepts Kubernetes prerelease and vendor versions.

Kubernetes before 1.26 retains the previous budget behavior. On 1.26 the policy requires the alpha feature gate; on 1.27 and later it is enabled by default. Rendering the field on 1.26 preserves clusters with the feature enabled. The chart adds no configuration or helper.

Edit the five source templates, then copy those files to the published mirror. Budget tests explicitly select a modern Kubernetes version and add regression cases for 1.21, 1.25 and 1.26 across all five templates. Disabled budgets and default snapshots stay unchanged.

## Rollout

The guard changes only enabled budgets on clusters older than 1.26. Newer manifests retain the same budgets and policy. No application image, stateful resource, credential, replica count, or extraction contract changes. Development, staging and production receive the guard through their next chart upgrade. No cluster deployment is part of this change. Rollback is reverting the guard in both chart copies, which restores the old-cluster validation failure.
