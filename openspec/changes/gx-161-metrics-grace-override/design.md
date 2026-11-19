## Implementation

Remove the Metrics replicas schema's `required` entry for `desired`. Retain the current fallback for an absent replicas map. For a nonempty map that omits `desired`, merge its values into a fresh map containing `desired: 1`. This preserves explicit zero and avoids mutating shared Helm values.

Keep the `values.yaml` defaults and grace calculation. Copy the changed source schema and helper into `helm/`.

## Verification

Extend the existing bare Metrics grace override test to omit `desired` explicitly and require one replica. Cover explicit zero and three replicas with the same grace override. Run the Helm production gate and reproduce a reused-values upgrade with Helm's upgrade action against the previous chart.
