resource "helm_release" "layout_map_service" {
  name       = "${var.layout_internal.service}-map"
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
        pull          = var.layout_internal.map.image.pull
        repository    = "${var.app_internal.repo_url}/${var.layout_internal.map.image.repository}${local.container_suffix}"
        tag           = var.layout_internal.map.image.tag
      }
      nodeSelector    = {
        node          = local.node_assignment.layout_map
      }
      replicas        = {
        cooldown      = var.layout_resources.map.replicas.cooldown
        max           = local.replicas.layout.map.max
        min           = local.replicas.layout.map.min
        threshold     = var.layout_resources.map.replicas.threshold
      }
      resources       = var.layout_resources.map.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service         = {
        name          = "${var.layout_internal.service}-map"
        namespace     = var.app_internal.namespace
        version       = var.layout_internal.version
      }
    })
  ]
}