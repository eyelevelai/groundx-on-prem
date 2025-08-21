locals {
  pp_image_tag = var.pre_process_internal.image.tag != "latest" ? var.pre_process_internal.image.tag : var.deployment_type.tag
}

resource "helm_release" "pre_process_service" {
  name       = var.pre_process_internal.service
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/pre-process/helm_chart"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        groundx       = "${var.groundx_internal.service}.${var.app_internal.namespace}.svc.cluster.local"
      }
      image           = {
        pull          = var.pre_process_internal.image.pull
        repository    = "${var.app_internal.repo_url}/${var.pre_process_internal.image.repository}${local.container_suffix}"
        tag           = local.pp_image_tag
      }
      nodeSelector    = {
        node          = local.node_assignment.pre_process
      }
      replicas        = {
        cooldown      = var.pre_process_resources.replicas.cooldown
        max           = local.replicas.pre_process.max
        min           = local.replicas.pre_process.min
        threshold     = var.pre_process_resources.replicas.threshold
      }
      resources       = var.pre_process_resources.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      service         = {
        name          = var.pre_process_internal.service
        namespace     = var.app_internal.namespace
        version       = var.pre_process_internal.version
      }
      username        = local.pp_image_tag == "chainguard" ? "nonroot" : "golang"
    })
  ]

  timeout = 300
}