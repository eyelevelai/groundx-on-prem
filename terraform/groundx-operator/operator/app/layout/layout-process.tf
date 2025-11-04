locals {
  lp_image_tag = var.layout_internal.process.image.tag != "latest" ? var.layout_internal.process.image.tag : var.deployment_type.tag
}

resource "helm_release" "layout_process_service" {
  name       = "${var.layout_internal.service}-process"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/layout/process/helm_chart"

  disable_openapi_validation = var.cluster.type == "openshift"

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
        tag           = local.lp_image_tag
      }
      nodeSelector    = {
        node          = local.node_assignment.layout_process
      }
      opts            = local.lp_image_tag == "chainguard" ? " export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python &&" : ""
      replicas        = {
        cooldown      = var.layout_resources.process.replicas.cooldown
        max           = local.replicas.layout.process.max
        min           = local.replicas.layout.process.min
        threshold     = var.layout_resources.process.replicas.threshold
      }
      resources       = var.layout_resources.process.resources
      securityContext = {
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
      }
      service         = {
        name          = "${var.layout_internal.service}-process"
        namespace     = var.app_internal.namespace
        version       = var.layout_internal.version
      }
    })
  ]

  timeout = 300
}