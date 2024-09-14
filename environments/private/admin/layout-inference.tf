resource "helm_release" "layout_inference_service" {
  count = local.create_layout ? 0 : 0

  depends_on = [kubernetes_namespace.eyelevel, kubernetes_config_map.layout_config_file]

  name       = "${var.layout_service.name}-inference-cluster"
  namespace  = var.namespace

  chart      = "${path.module}/../../../modules/layout/inference/helm_chart"

  values = [
    yamlencode({
      dependencies = {
        cache = "${var.cache_service}.${var.namespace}.svc.cluster.local"
      }
      image = var.internet_access ? var.layout_inference_image : var.layout_inference_image_op
      securityContext = {
        runAsUser  = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service = {
        name      = "${var.layout_service.name}-inference"
        namespace = var.namespace
        version   = var.layout_service.version
      }
    })
  ]

  timeout = 1800
}