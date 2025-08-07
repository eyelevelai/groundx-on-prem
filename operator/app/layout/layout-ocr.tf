resource "helm_release" "layout_ocr_service" {
  count = var.layout.ocr.type == "google" ? 0 : 1

  name       = "${var.layout_internal.service}-ocr"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/layout/process/helm_chart"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        cache         = "${local.cache_settings.addr} ${local.cache_settings.port}"
        file          = "${local.file_settings.dependency} ${local.file_settings.port}"
      }
      image           = {
        pull          = var.layout_internal.ocr.image.pull
        repository    = "${var.app_internal.repo_url}/${var.layout_internal.ocr.image.repository}${local.container_suffix}"
        tag           = var.layout_internal.ocr.image.tag
      }
      nodeSelector    = {
        node          = local.node_assignment.layout_ocr
      }
      replicas        = {
        cooldown      = var.layout_resources.ocr.replicas.cooldown
        max           = local.replicas.layout.ocr.max
        min           = local.replicas.layout.ocr.min
        threshold     = var.layout_resources.ocr.replicas.threshold
      }
      resources       = var.layout_resources.ocr.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service         = {
        name          = "${var.layout_internal.service}-ocr"
        namespace     = var.app_internal.namespace
        version       = var.layout_internal.version
      }
    })
  ]
}