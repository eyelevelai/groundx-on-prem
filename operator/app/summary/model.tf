resource "helm_release" "summary_model_pv" {
  count = local.create_summary ? 1 : 0

  name       = "${var.summary_internal.service}-model-pv"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/storage/helm_chart"

  values = [
    yamlencode({
      access      = var.summary_internal.inference.pv.access
      capacity    = var.summary_internal.inference.pv.capacity
      mount       = var.summary_internal.inference.pv.mount
      name        = "${var.summary_internal.service}-model-pv"
      storage     = var.cluster.pv.name
      service     = {
        name      = "${var.summary_internal.service}-inference"
        namespace = var.app_internal.namespace
      }
    })
  ]
}