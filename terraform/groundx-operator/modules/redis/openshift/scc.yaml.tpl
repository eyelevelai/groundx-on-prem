apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: redis-enterprise-scc-v2
  labels:
    app.kubernetes.io/managed-by: "Helm"
  annotations:
    app.kubernetes.io/managed-by: "Helm"
allowedCapabilities:
  - SYS_RESOURCE
allowPrivilegeEscalation: false
runAsUser:
  type: MustRunAs
  uid: ${run_as_user}
fsGroup:
  type: MustRunAs
  ranges:
    - min: ${fs_group}
      max: ${fs_group}
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny