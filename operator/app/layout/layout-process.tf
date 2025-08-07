resource "helm_release" "layout_process_service" {
  name       = "${var.layout_internal.service}-process"
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
        pull          = var.layout_internal.process.image.pull
        repository    = "${var.app_internal.repo_url}/${var.layout_internal.process.image.repository}${local.container_suffix}"
        tag           = var.layout_internal.process.image.tag
      }
      nodeSelector    = {
        node          = local.node_assignment.layout_process
      }
      replicas        = {
        cooldown      = var.layout_resources.process.replicas.cooldown
        max           = local.replicas.layout.process.max
        min           = local.replicas.layout.process.min
        threshold     = var.layout_resources.process.replicas.threshold
      }
      resources       = var.layout_resources.process.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service         = {
        name          = "${var.layout_internal.service}-process"
        namespace     = var.app_internal.namespace
        version       = var.layout_internal.version
      }
    })
  ]
}