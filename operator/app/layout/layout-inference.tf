resource "helm_release" "layout_inference_service" {
  name       = "${var.layout_internal.service}-inference"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/layout/inference/helm_chart"

  timeout    = 600

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      createSymlink   = local.create_symlink ? true : false
      dependencies    = {
        cache         = "${local.cache_settings.addr} ${local.cache_settings.port}"
        file          = "${local.file_settings.dependency} ${local.file_settings.port}"
      }
      image           = {
        pull          = var.layout_internal.inference.image.pull
        repository    = "${var.app_internal.repo_url}/${var.layout_internal.inference.image.repository}${local.op_container_suffix}"
        tag           = var.layout_internal.inference.image.tag
      }
      local           = var.cluster.environment == "local"
      nodeSelector    = {
        node          = local.node_assignment.layout_inference
      }
      replicas        = {
        cooldown      = var.layout_resources.inference.replicas.cooldown
        max           = local.replicas.layout.inference.max
        min           = local.replicas.layout.inference.min
        threshold     = var.layout_resources.inference.replicas.threshold
      }
      resources       = var.layout_resources.inference.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service         = {
        name          = "${var.layout_internal.service}-inference"
        namespace     = var.app_internal.namespace
        version       = var.layout_internal.version
      }
    })
  ]
}