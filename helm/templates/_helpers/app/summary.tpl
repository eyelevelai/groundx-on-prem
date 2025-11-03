{{- define "groundx.summary.serviceName" -}}
{{- $in := .Values.summary | default dict -}}
{{ dig "serviceName" "summary" $in }}
{{- end }}

{{- define "groundx.summary.create" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $urlEmpty := eq (dig "url" "" $ex) "" -}}
{{- $stype := lower (coalesce (dig "serviceType" "" $ex) "eyelevel") | trim -}}
{{- $svcAllowed := or (eq $stype "openai") (eq $stype "openai-base64") (eq $stype "azure") -}}
{{- and $urlEmpty (not $svcAllowed) -}}
{{- end }}

{{- define "groundx.summary.apiKey" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- coalesce (dig "apiKey" "" $ex) (include "groundx.admin.apiKey" .) | default "" -}}
{{- end }}

{{- define "groundx.summary.baseUrl" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.summary.create" . -}}
{{- if eq $ic "true" -}}
{{ include "groundx.summary.api.serviceUrl" . }}
{{- else -}}
{{ dig "url" "" $ex }}
{{- end -}}
{{- end }}

{{- define "groundx.summary.defaultKitId" -}}
{{- $in := .Values.summary | default dict -}}
{{ dig "defaultKitId" 0 $in }}
{{- end }}

{{- define "groundx.summary.serviceType" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{ coalesce (dig "serviceType" "" $ex) "eyelevel" }}
{{- end }}
