locals {
  nvidia_operator_daemonset_tolerations = [
    {
      key      = "nvidia.com/gpu"
      operator = "Exists"
      effect   = "NoSchedule"
    },
    {
      key      = "eyelevel_node"
      operator = "Exists"
      effect   = "NoSchedule"
    }
  ]

  nvidia_operator_nfd_worker_tolerations = [
    {
      key      = "node-role.kubernetes.io/master"
      operator = "Equal"
      value    = ""
      effect   = "NoSchedule"
    },
    {
      key      = "node-role.kubernetes.io/control-plane"
      operator = "Equal"
      value    = ""
      effect   = "NoSchedule"
    },
    {
      key      = "nvidia.com/gpu"
      operator = "Exists"
      effect   = "NoSchedule"
    },
    {
      key      = "eyelevel_node"
      operator = "Exists"
      effect   = "NoSchedule"
    }
  ]
}

resource "helm_release" "gpu_operator" {
  count = (var.cluster.has_nvidia || local.is_openshift) ? 0 : 1

  name             = var.cluster_internal.nvidia.name

  repository       = var.cluster_internal.nvidia.chart.repository
  chart            = var.cluster_internal.nvidia.chart.name
  version          = var.cluster_internal.nvidia.chart.version

  namespace        = var.cluster_internal.nvidia.namespace
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  reset_values     = true
  replace          = true

  values = var.cluster.type == "aks" ? [
    yamlencode({
      daemonsets = {
        tolerations = local.nvidia_operator_daemonset_tolerations
      }
      "node-feature-discovery" = {
        worker = {
          tolerations = local.nvidia_operator_nfd_worker_tolerations
        }
      }
      operator = {
        runtimeClass = "nvidia-container-runtime"
      }
    })
  ] : [
    yamlencode({
      daemonsets = {
        tolerations = local.nvidia_operator_daemonset_tolerations
      }
      "node-feature-discovery" = {
        worker = {
          tolerations = local.nvidia_operator_nfd_worker_tolerations
        }
      }
      operator = {
        runtimeClass = "nvidia"
      }
    })
  ]
}
