data "external" "get_uid_gid" {
  count = local.is_openshift ? 1 : 0

  program = ["sh", "-c", <<-EOT
    kubectl get namespace ${var.app_internal.namespace} -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' | cut -d'/' -f1 | xargs -I {} jq -n --arg uid {} --arg gid {} '{"UID": $uid, "GID": $gid}'
  EOT
  ]
}