{{- define "groundx.summary.serviceName" -}}
{{- $in := .Values.summary | default dict -}}
{{ dig "serviceName" "summary" $in }}
{{- end }}

{{- define "groundx.summary.create" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $stype := lower (coalesce (dig "serviceType" "" $ex) "on-prem") -}}
{{- $stypeNorm := replace $stype "-" "" -}}
{{- and (or (empty (dig "apiKey" "" $ex)) (empty (dig "url" "" $ex))) (ne $stypeNorm "openai") -}}
{{- end }}

{{- define "groundx.summary.apiKey" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- coalesce (dig "apiKey" "" $ex) (include "groundx.admin.apiKey" .) -}}
{{- end }}

{{- define "groundx.summary.baseURL" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "url" "" $ex) (printf "http://%s-api.%s.svc.cluster.local" $svc $ns) -}}
{{- end }}

{{- define "groundx.summary.defaultKitId" -}}
{{- $in := .Values.summary | default dict -}}
{{ dig "defaultKitId" 0 $in }}
{{- end }}

{{- define "groundx.summary.serviceType" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- coalesce (dig "serviceType" "" $ex) "on-prem" -}}
{{- end }}
