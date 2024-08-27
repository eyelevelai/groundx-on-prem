provider "helm" {
  kubernetes {
    config_path = var.kube_config_path
  }
}

data "external" "get_uid_gid" {
  program = ["sh", "-c", <<-EOT
    kubectl get namespace ${kubernetes_namespace.eyelevel.metadata[0].name} -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' | cut -d'/' -f1 | xargs -I {} jq -n --arg uid {} --arg gid {} '{"UID": $uid, "GID": $gid}'
  EOT
  ]
}
