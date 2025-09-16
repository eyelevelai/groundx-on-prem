{{- define "groundx.db.serviceName" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "serviceName" "db" $in }}
{{- end }}

{{- define "groundx.db.existing" -}}
{{- $ex := .Values.db.existing | default dict -}}
{{ not (or (empty (dig "ro" "" $ex)) (empty (dig "rw" "" $ex))) }}
{{- end }}

{{- define "groundx.db.create" -}}
{{- $in := .Values.db | default dict -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.db.backup" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "backup" "false" $in }}
{{- end }}

{{- define "groundx.db.disableUnsafeChecks" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "disableUnsafeChecks" "true" $in }}
{{- end }}

{{- define "groundx.db.logcollector" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "logcollector" "false" $in }}
{{- end }}

{{- define "groundx.db.pmm" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "pmm" "false" $in }}
{{- end }}

{{- define "groundx.db.pvSize" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "pvSize" "10Gi" $in }}
{{- end }}

{{- define "groundx.db.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.db.serviceName" . -}}
{{- printf "%s-cluster-pxc-db-haproxy.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.db.ro" -}}
{{- $ex := .Values.db.existing | default dict -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ coalesce (dig "ro" "" $ex) (dig "rw" "" $ex) }}
{{- else -}}
{{ include "groundx.db.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.db.rw" -}}
{{- $ex := .Values.db.existing | default dict -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ coalesce (dig "rw" "" $ex) (dig "ro" "" $ex) }}
{{- else -}}
{{ include "groundx.db.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.db.port" -}}
{{- $ex := .Values.db.existing | default dict -}}
{{- $in := .Values.db | default dict -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" "" $ex }}
{{- else -}}
{{ dig "port" 3306 $in }}
{{- end -}}
{{- end }}
