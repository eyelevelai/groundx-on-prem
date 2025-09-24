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

{{- define "groundx.db.maxIdle" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "maxIdle" 5 $in }}
{{- end }}

{{- define "groundx.db.maxOpen" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "maxOpen" 10 $in }}
{{- end }}

{{- define "groundx.db.ro" -}}
{{- $ex := .Values.db.existing | default dict -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ coalesce (dig "ro" "" $ex) (dig "rw" "" $ex) }}
{{- else -}}
{{- $name := include "groundx.db.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- printf "%s-cluster-haproxy-replicas.%s.svc.cluster.local" $name $ns -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.rw" -}}
{{- $ex := .Values.db.existing | default dict -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ coalesce (dig "rw" "" $ex) (dig "ro" "" $ex) }}
{{- else -}}
{{- $name := include "groundx.db.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- printf "%s-cluster-haproxy.%s.svc.cluster.local" $name $ns -}}
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
