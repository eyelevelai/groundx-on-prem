{{- define "groundx.search.serviceName" -}}
{{- $in := .Values.search | default dict -}}
{{ dig "serviceName" "opensearch" $in }}
{{- end }}

{{- define "groundx.search.existing" -}}
{{- $in := .Values.search | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{ not (empty (dig "url" "" $ex)) }}
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
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $url := include "groundx.search.baseURL" . -}}
{{- $parts := splitList "://" $url -}}
{{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
{{ index $parts 1 }}
{{- else -}}
{{ $url }}
{{- end -}}
{{- else -}}
{{ include "groundx.search.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.search.baseURL" -}}
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $in := .Values.search | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{ dig "url" "" $ex }}
{{- else -}}
{{- $port := include "groundx.search.port" . -}}
{{- $svc := include "groundx.search.serviceHost" . -}}
{{ printf "https://%s:%v" $svc $port }}
{{- end -}}
{{- end }}

{{- define "groundx.search.port" -}}
{{- $ic := include "groundx.search.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $url := include "groundx.search.baseURL" . }}
{{- $sch := "http" -}}
{{- $sparts := splitList "://" $url -}}
{{- $domain := include "groundx.search.baseURL" . -}}
{{- if and (kindIs "slice" $sparts) (eq (len $sparts) 2) -}}
{{- $sch = index $sparts 0 -}}
{{- $domain = index $sparts 1 -}}
{{- end -}}
{{- $pparts := splitList ":" $domain -}}
{{- if and (kindIs "slice" $pparts) (eq (len $pparts) 2) -}}
{{ index $pparts 1 }}
{{- else if eq $sch "https" -}}
443
{{- else -}}
80
{{- end -}}
{{- else -}}
{{- $in := .Values.search | default dict -}}
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
