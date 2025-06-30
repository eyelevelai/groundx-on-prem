resource "helm_release" "ranker_model_pv" {
  count      = local.ingest_only ? 0 : 1

  name       = "${var.ranker_internal.service}-model-pv"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/storage/helm_chart"

  values = [
    yamlencode({
      access      = var.ranker_internal.inference.pv.access
      capacity    = var.ranker_internal.inference.pv.capacity
      mount       = var.ranker_internal.inference.pv.mount
      name        = "${var.ranker_internal.service}-model-pv"
      storage     = var.cluster.pv.name
      service     = {
        name      = "${var.ranker_internal.service}-inference"
        namespace = var.app_internal.namespace
      }
    })
  ]
}