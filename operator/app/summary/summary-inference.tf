resource "helm_release" "summary_inference_service" {
  count = local.create_summary ? 1 : 0

  name       = "${var.summary_internal.service}-inference-cluster"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/summary/inference/helm_chart"

  timeout    = 1200

  values = [
    yamlencode({
      dependencies    = {
        cache         = "${local.cache_settings.addr} ${local.cache_settings.port}"
      }
      image           = var.cluster.internet_access ? var.summary_internal.inference.image : var.summary_internal.inference.image_op
      nodeSelector    = {
        node          = var.cluster_internal.nodes.gpu_summary
      }
      replicas        = 1
      resources       = var.summary_resources.inference.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service = {
        name          = "${var.summary_internal.service}-inference"
        namespace     = var.app_internal.namespace
        version       = var.summary_internal.version
      }
    })
  ]
}