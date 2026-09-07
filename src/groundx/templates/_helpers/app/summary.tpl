{{- define "groundx.summary.serviceName" -}}
{{- $in := .Values.summary | default dict -}}
{{ dig "serviceName" "summary" $in }}
{{- end }}

{{- define "groundx.summary.existingConfigured" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $hasService := and (hasKey $ex "serviceType") (ne (get $ex "serviceType" | toString | trim) "") -}}
{{- $hasUrl := and (hasKey $ex "url") (ne (get $ex "url" | toString | trim) "") -}}
{{- if or $hasService $hasUrl -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.summary.validateEngines" -}}
{{- $engines := .Values.engines | default dict -}}
{{- if and (eq (include "groundx.summary.existingConfigured" .) "true") (eq (len $engines) 0) -}}
  {{- fail "explicit summary configuration requires engines.<name>.engineId" -}}
{{- end -}}
{{- range $name, $engine := $engines -}}
  {{- if eq (get $engine "engineId" | default "" | toString | trim) "" -}}
    {{- fail (printf "summary engine %s requires engines.%s.engineId" $name $name) -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.summary.create" -}}
{{- include "groundx.summary.validateEngines" . -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $stype := lower (coalesce (dig "serviceType" "" $ex) "eyelevel") | trim -}}
{{- $existingConfigured := eq (include "groundx.summary.existingConfigured" .) "true" -}}
{{- $engines := .Values.engines | default dict -}}
{{- $localNeeded := and (eq (len $engines) 0) (not $existingConfigured) -}}
{{- range $engine := $engines -}}
  {{- $explicitService := coalesce (get $engine "service") (get $engine "serviceType") "" | toString | lower | trim -}}
  {{- $service := coalesce $explicitService $stype | default "eyelevel" | toString | lower | trim -}}
  {{- $hasBaseUrl := and (hasKey $engine "baseUrl") (ne (get $engine "baseUrl" | toString | trim) "") -}}
  {{- if and (eq $service "eyelevel") (not $hasBaseUrl) (or (not $existingConfigured) (eq $explicitService "eyelevel")) -}}
    {{- $localNeeded = true -}}
  {{- end -}}
{{- end -}}
{{- $localNeeded -}}
{{- end }}

{{- define "groundx.summary.apiKey" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- if hasKey $ex "apiKey" -}}
{{ get $ex "apiKey" }}
{{- else if eq (include "groundx.summary.existingConfigured" .) "false" -}}
{{ include "groundx.admin.apiKey" . }}
{{- else -}}
{{ "" }}
{{- end -}}
{{- end }}

{{- define "groundx.summary.baseUrl" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $configuredUrl := dig "url" "" $ex | trim -}}
{{- $ic := include "groundx.summary.create" . -}}
{{- if ne $configuredUrl "" -}}
{{ $configuredUrl }}
{{- else if eq $ic "true" -}}
{{ include "groundx.summary.api.serviceUrl" . }}
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
