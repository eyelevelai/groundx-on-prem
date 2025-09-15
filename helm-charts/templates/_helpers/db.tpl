{{- define "groundx.db.create" -}}
{{- $ex := dig "existing" dict .Values.db -}}
{{- or (empty (dig "port" "" $ex)) (empty (dig "ro" "" $ex)) (empty (dig "rw" "" $ex)) -}}
{{- end }}

{{- define "groundx.db.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := (.Values.db.internal.serviceName | default "") -}}
{{- printf "%s-cluster-pxc-db-haproxy.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.db.ro" -}}
{{- $db := .Values.db | default dict -}}
{{- $ext := dig "existing" "ro" "" $db -}}
{{- if $ext -}}
{{- $ext -}}
{{- else -}}
{{- include "groundx.db.serviceHost" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.rw" -}}
{{- $db := .Values.db | default dict -}}
{{- $ext := dig "existing" "rw" "" $db -}}
{{- if $ext -}}
{{- $ext -}}
{{- else -}}
{{- include "groundx.db.serviceHost" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.port" -}}
{{- $db := .Values.db | default dict -}}
{{- $ext := dig "existing" "port" "" $db -}}
{{- if $ext -}}
{{- $ext -}}
{{- else -}}
{{- dig "internal" "port" 3306 $db -}}
{{- end -}}
{{- end }}
