resource "kubernetes_storage_class_v1" "local_storage" {
  count = var.cluster.pv.type == "empty" ? 1 : 0

  metadata {
    name = var.cluster.pv.name
  }

  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "WaitForFirstConsumer"
}