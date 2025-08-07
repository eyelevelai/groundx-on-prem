resource "helm_release" "layout_save_service" {
  name       = "${var.layout_internal.service}-save"
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
        pull          = var.layout_internal.save.image.pull
        repository    = "${var.app_internal.repo_url}/${var.layout_internal.save.image.repository}${local.container_suffix}"
        tag           = var.layout_internal.save.image.tag
      }
      nodeSelector    = {
        node          = local.node_assignment.layout_save
      }
      replicas        = {
        cooldown      = var.layout_resources.save.replicas.cooldown
        max           = local.replicas.layout.save.max
        min           = local.replicas.layout.save.min
        threshold     = var.layout_resources.save.replicas.threshold
      }
      resources       = var.layout_resources.save.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service         = {
        name          = "${var.layout_internal.service}-save"
        namespace     = var.app_internal.namespace
        version       = var.layout_internal.version
      }
    })
  ]
}