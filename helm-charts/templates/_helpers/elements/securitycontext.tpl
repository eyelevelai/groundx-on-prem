{{- define "groundx.renderSecurityContext" -}}
{{- $ctx := .ctx -}}
{{- $indent := .indent | default 0 -}}
{{- $root := .root -}}
{{- $user := .user -}}
{{- if not $ctx }}
  {{- $isOS := eq (dig "type" "" $root.Values.cluster) "openshift" -}}
  {{- if $isOS -}}
    {{- $ctx = dict
        "runAsNonRoot" true
        "allowPrivilegeEscalation" false
        "seccompProfile" (dict "type" "RuntimeDefault")
        "capabilities" (dict "drop" (list "ALL"))
      -}}
  {{- else -}}
    {{- $ctx = dict
        "runAsNonRoot" true
        "allowPrivilegeEscalation" false
        "seccompProfile" (dict "type" "RuntimeDefault")
        "capabilities" (dict "drop" (list "ALL"))
        "runAsUser" $user
        "runAsGroup" $user
        "fsGroup" $user
        "fsGroupChangePolicy" "OnRootMismatch"
      -}}
  {{- end }}
{{- end }}
{{- if $ctx }}
{{- printf "%*ssecurityContext:" (int $indent) "" }}{{ $ctx | toYaml | nindent (int (add $indent 2)) }}
{{- end }}
{{- end }}
