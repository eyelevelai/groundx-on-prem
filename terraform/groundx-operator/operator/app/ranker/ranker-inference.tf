locals {
  ri_image_tag = var.ranker_internal.inference.image.tag != "latest" ? var.ranker_internal.inference.image.tag : var.deployment_type.tag
}

resource "helm_release" "ranker_inference_service" {
  count      = local.ingest_only ? 0 : 1

  name       = "${var.ranker_internal.service}-inference"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/ranker/inference/helm_chart"

  timeout    = 1200

  values = [
    yamlencode({
      busybox            = var.app_internal.busybox
      cluster             = var.cluster_arch
      createSymlink       = local.create_symlink ? true : false
      dependencies        = {
        cache             = "${local.cache_settings.addr} ${local.cache_settings.port}"
      }
      image               = {
        pull              = var.ranker_internal.inference.image.pull
        repository        = "${var.app_internal.repo_url}/${var.ranker_internal.inference.image.repository}${local.op_container_suffix}"
        tag               = local.ri_image_tag
      }
      model               = local.ranker_model.version
      nodeSelector        = {
        node              = local.node_assignment.ranker_inference
      }
      pv                  = {
        access            = var.ranker_internal.inference.pv.access
        capacity          = var.ranker_internal.inference.pv.capacity
        name              = "${var.ranker_internal.service}-model"
        storage           = var.cluster.pv.name
      }
      replicas            = {
        cooldown          = var.ranker_resources.inference.replicas.cooldown
        max               = coalesce(max(1, ceil(local.baseline_search / local.ranker_model.throughput)), local.replicas.ranker.inference.max)
        min               = coalesce(max(1, ceil(local.baseline_search / local.ranker_model.throughput)), local.replicas.ranker.inference.min)
        threshold         = var.ranker_resources.inference.replicas.threshold
      }
      resources           = var.ranker_resources.inference.resources
      securityContext     = {
        fsGroup           = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsGroup        = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsUser         = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
      }
      service             = {
        name              = "${var.ranker_internal.service}-inference"
        namespace         = var.app_internal.namespace
        version           = var.ranker_internal.version
      }
      type                = var.cluster.type
      waitForDependencies = true
    })
  ]
}