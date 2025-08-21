locals {
  p_image_tag = var.process_internal.image.tag != "latest" ? var.process_internal.image.tag : var.deployment_type.tag
}

resource "helm_release" "process_service" {
  name       = var.process_internal.service
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/process/helm_chart"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        groundx       = "${var.groundx_internal.service}.${var.app_internal.namespace}.svc.cluster.local"
      }
      image           = {
        pull          = var.process_internal.image.pull
        repository    = "${var.app_internal.repo_url}/${var.process_internal.image.repository}${local.container_suffix}"
        tag           = local.p_image_tag
      }
      nodeSelector    = {
        node          = local.node_assignment.process
      }
      replicas        = {
        cooldown      = var.process_resources.replicas.cooldown
        max           = local.replicas.process.max
        min           = local.replicas.process.min
        threshold     = var.process_resources.replicas.threshold
      }
      resources       = var.process_resources.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      service         = {
        name          = var.process_internal.service
        namespace     = var.app_internal.namespace
        version       = var.process_internal.version
      }
      username        = local.p_image_tag == "chainguard" ? "nonroot" : "golang"
    })
  ]

  timeout = 300
}