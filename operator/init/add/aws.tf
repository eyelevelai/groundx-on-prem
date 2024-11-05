resource "kubernetes_storage_class" "eyelevel_ebs_pv" {
  count = var.cluster.environment == "aws" ? 1 : 0

  metadata {
    name = "${var.cluster_internal.pv.name}"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner  = "ebs.csi.aws.com"
  reclaim_policy       = "Delete"
  volume_binding_mode  = "WaitForFirstConsumer"

  parameters = {
    type = var.cluster_internal.pv.type
  }
}