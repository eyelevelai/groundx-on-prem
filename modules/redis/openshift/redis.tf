resource "null_resource" "apply_redis_operator" {
  count = local.create_redis && !local.create_openshift ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      VERSION=$(curl --silent https://api.github.com/repos/RedisLabs/redis-enterprise-k8s-docs/releases/latest | grep tag_name | awk -F'"' '{print $4}')
      kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/$VERSION/bundle.yaml --namespace=${var.namespace}      
    EOT
  }
}

resource "null_resource" "apply_redis_openshift_operator" {
  count = local.create_redis && local.create_openshift ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      VERSION=$(curl --silent https://api.github.com/repos/RedisLabs/redis-enterprise-k8s-docs/releases/latest | grep tag_name | awk -F'"' '{print $4}') && oc apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/$VERSION/openshift.bundle.yaml --namespace=${var.namespace}
    EOT
  }
}

data "template_file" "scc_yaml" {
  template = file("${path.module}/../../modules/redis/helm_chart/openshift/scc.yaml.tpl")

  vars = {
    run_as_user = tonumber(data.external.get_uid_gid.result.UID)
    fs_group    = tonumber(data.external.get_uid_gid.result.GID)
  }
}

resource "null_resource" "apply_openshift_scc" {
  count = local.create_redis && local.create_openshift ? 1 : 0

  depends_on = [null_resource.apply_redis_openshift_operator]

  provisioner "local-exec" {
    command = <<-EOT
      echo "${data.template_file.scc_yaml.rendered}" > "${path.module}/../../modules/redis/helm_chart/openshift/scc.yaml"
      oc apply -f "${path.module}/../../modules/redis/helm_chart/openshift/scc.yaml" --namespace=${var.namespace}
    EOT
  }
}

resource "null_resource" "apply_openshift_role_binding" {
  count = local.create_redis && local.create_openshift ? 1 : 0

  depends_on = [null_resource.apply_openshift_scc]

  provisioner "local-exec" {
    command = <<-EOT
      oc adm policy add-scc-to-user redis-enterprise-scc-v2 system:serviceaccount:${var.namespace}:redis-enterprise-operator
    EOT
  }
}

resource "helm_release" "redis_cluster" {
  count = local.create_redis && !local.create_openshift ? 1 : 0

  depends_on = [null_resource.apply_redis_operator]
  name       = "${var.cache_service}-cluster"
  namespace  = var.namespace
  chart      = "${path.module}/../../modules/redis/helm_chart"

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = var.cache_cpu_requests
          memory = var.cache_memory_requests
        }
      }
      service = {
        nodes     = var.cache_replicas
        version   = var.cache_bundle_version
      }
    })
  ]
}


resource "helm_release" "redis_openshift_cluster" {
  count = local.create_redis && local.create_openshift ? 0 : 0

  depends_on = [null_resource.apply_openshift_role_binding]
  name       = "${var.cache_service}-cluster"
  namespace  = var.namespace
  chart      = "${path.module}/../../modules/redis/helm_chart"

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = var.cache_cpu_requests
          memory = var.cache_memory_requests
        }
      }
      service = {
        nodes     = var.cache_replicas
        version   = var.cache_bundle_version
      }
    })
  ]
}