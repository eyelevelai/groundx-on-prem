{{- define "groundx.summary.create" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- $stype := lower (coalesce (dig "serviceType" "" $ex) "on-prem") -}}
{{- $stypeNorm := replace $stype "-" "" -}}
{{- and (or (empty (dig "apiKey" "" $ex)) (empty (dig "url" "" $ex))) (ne $stypeNorm "openai") -}}
{{- end }}

{{- define "groundx.summary.apiKey" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- coalesce (dig "apiKey" "" $ex) (.Values.admin.apiKey | default "") -}}
{{- end }}

{{- define "groundx.summary.baseURL" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- $in := .Values.summary.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "url" "" $ex) (printf "http://%s-api.%s.svc.cluster.local" (dig "serviceName" "summary" $in) $ns) -}}
{{- end }}

{{- define "groundx.summary.serviceType" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- coalesce (dig "serviceType" "" $ex) "on-prem" -}}
{{- end }}
