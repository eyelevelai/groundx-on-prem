{{- define "groundx.renderSecurityContext" -}}
{{- $ctx := .ctx | default dict -}}
{{- $indent := .indent | default 0 -}}
{{- $root := .root -}}
{{- $ct := include "groundx.clusterType" $root -}}
{{- $user := .user | int | default 1001 -}}
{{- $prefix := .prefix | default "securityContext" -}}
{{- $cfg := .cfg | default "full" -}}
{{- if lt (len $ctx) 1 }}
  {{- $isOS := eq $ct "openshift" -}}
  {{- if eq $cfg "spec" -}}
    {{- if $isOS -}}
      {{- $ctx = dict
          "runAsNonRoot" true
          "seccompProfile" (dict "type" "RuntimeDefault")
        -}}
    {{- else -}}
      {{- $ctx = dict
          "runAsNonRoot" true
          "seccompProfile" (dict "type" "RuntimeDefault")
          "runAsUser" $user
          "runAsGroup" $user
          "fsGroup" $user
          "fsGroupChangePolicy" "OnRootMismatch"
        -}}
    {{- end }}
  {{- else if eq $cfg "container" -}}
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
        -}}
    {{- end }}
  {{- else -}}
    {{- if $isOS -}}
      {{- $ctx = dict
          "runAsNonRoot" true
          "seccompProfile" (dict "type" "RuntimeDefault")
        -}}
    {{- else -}}
      {{- $ctx = dict
          "runAsNonRoot" true
          "seccompProfile" (dict "type" "RuntimeDefault")
          "runAsUser" $user
          "runAsGroup" $user
        -}}
    {{- end }}
  {{- end }}
{{- end }}
{{- if $ctx }}
{{- printf "%*s%s:" (int $indent) "" $prefix }}{{ $ctx | toYaml | nindent (int (add $indent 2)) }}
{{- end }}
{{- end }}
