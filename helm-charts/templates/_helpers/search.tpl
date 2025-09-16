{{- define "groundx.search.serviceName" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "serviceName" "search" $in }}
{{- end }}

{{- define "groundx.search.existing" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{ not (or (empty (dig "domain" "" $ex)) (empty (dig "url" "" $ex))) }}
{{- end }}

{{- define "groundx.search.create" -}}
{{- $in := .Values.search | default dict -}}
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.search.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.search.serviceName" . -}}
{{- printf "%s-cluster-master.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.search.baseDomain" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "domain" "" $ex }}
{{- else -}}
{{ include "groundx.search.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.search.port" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $in := .Values.search | default dict -}}
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" "" $ex }}
{{- else -}}
{{ dig "port" 9200 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.search.baseURL" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $ic := include "groundx.search.serviceHost" . -}}
{{- $port := include "groundx.search.port" . -}}
{{- if eq $ic "true" -}}
{{ dig "url" "" $ex }}
{{- else -}}
{{ printf "https://%s:%v" $ic $port }}
{{- end -}}
{{- end }}
