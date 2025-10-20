{{- define "groundx.db.node" -}}
{{- $in := .Values.db | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.db.serviceName" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "serviceName" "db" $in }}
{{- end }}

{{- define "groundx.db.existing" -}}
{{- $in := .Values.db | default dict -}}
{{- $ex := dig "existing" dict $in -}}
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

{{- define "groundx.db.customSQL" -}}
{{- $b := .Values.db | default dict -}}
{{- dig "customSQL" "" $b }}
{{- end }}

{{- define "groundx.db.dbName" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "dbName" "eyelevel" $in }}
{{- end }}

{{- define "groundx.db.maxIdle" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "maxIdle" 5 $in }}
{{- end }}

{{- define "groundx.db.maxOpen" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "maxOpen" 10 $in }}
{{- end }}

{{- define "groundx.db.password" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "password" "password" $in }}
{{- end }}

{{- define "groundx.db.port" -}}
{{- $in := .Values.file | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" 3306 $ex }}
{{- else -}}
{{ dig "port" 3306 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.db.privilegedPassword" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "privilegedPassword" "password" $in }}
{{- end }}

{{- define "groundx.db.privilegedUsername" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "privilegedUsername" "root" $in }}
{{- end }}

{{- define "groundx.db.ro" -}}
{{- $in := .Values.db | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- coalesce (dig "ro" "" $ex) (dig "rw" "" $ex) -}}
{{- else -}}
{{- $name := include "groundx.db.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- printf "%s-cluster-haproxy-replicas.%s.svc.cluster.local" $name $ns -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.rw" -}}
{{- $in := .Values.db | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.db.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- coalesce (dig "rw" "" $ex) (dig "ro" "" $ex) -}}
{{- else -}}
{{- $name := include "groundx.db.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- printf "%s-cluster-haproxy.%s.svc.cluster.local" $name $ns -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.username" -}}
{{- $in := .Values.db | default dict -}}
{{ dig "username" "eyelevel" $in }}
{{- end }}
