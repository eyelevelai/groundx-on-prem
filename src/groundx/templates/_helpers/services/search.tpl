{{- define "groundx.search.serviceName" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "serviceName" "opensearch" $in }}
{{- end }}

{{- define "groundx.search.existing" -}}
{{- $in := .Values.search | default dict -}}
{{- $ex := dig "existing" dict $in -}}
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
{{- $in := .Values.search | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "domain" "" $ex }}
{{- else -}}
{{ include "groundx.search.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.search.baseURL" -}}
{{- $in := .Values.search | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.search.serviceHost" . -}}
{{- $port := include "groundx.search.port" . -}}
{{- if eq $ic "true" -}}
{{ dig "url" "" $ex }}
{{- else -}}
{{ printf "https://%s:%v" $ic $port }}
{{- end -}}
{{- end }}

{{- define "groundx.search.port" -}}
{{- $in := .Values.search | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" "" $ex }}
{{- else -}}
{{ dig "port" 9200 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.search.indexName" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "indexName" "prod-1" $in }}
{{- end }}

{{- define "groundx.search.password" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "password" "R0otb_*t!kazs" $in }}
{{- end }}

{{- define "groundx.search.privilegedPassword" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "privilegedPassword" "R0otb_*t!kazs" $in }}
{{- end }}

{{- define "groundx.search.privilegedUsername" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "privilegedUsername" "admin" $in }}
{{- end }}

{{- define "groundx.search.username" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "username" "eyelevel" $in }}
{{- end }}
