{{- define "groundx.summary.serviceName" -}}
{{- $in := .Values.summary | default dict -}}
{{ dig "serviceName" "summary" $in }}
{{- end }}

{{- define "groundx.summary.validateAnthropic" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $summaryService := lower (coalesce (dig "serviceType" "" $ex) "eyelevel") | trim -}}
{{- $summaryUrl := dig "url" "" $ex | trim -}}
{{- $summaryApiKey := dig "apiKey" "" $ex | trim -}}
{{- $engines := .Values.engines | default dict -}}
{{- if and (eq $summaryService "anthropic") (eq (len $engines) 0) -}}
  {{- fail "summary Anthropic requires engines.<name>.engineId" -}}
{{- end -}}
{{- range $name, $engine := $engines -}}
  {{- $service := coalesce (get $engine "service") (get $engine "serviceType") $summaryService | default "" | toString | trim -}}
  {{- if eq $service "anthropic" -}}
    {{- if eq (get $engine "engineId" | default "" | toString | trim) "" -}}
      {{- fail (printf "summary Anthropic engine %s requires engines.%s.engineId" $name $name) -}}
    {{- end -}}
    {{- if eq (coalesce (get $engine "baseUrl") $summaryUrl | default "" | toString | trim) "" -}}
      {{- fail (printf "summary Anthropic engine %s requires engines.%s.baseUrl or summary.existing.url" $name $name) -}}
    {{- end -}}
    {{- if eq (coalesce (get $engine "apiKey") $summaryApiKey | default "" | toString | trim) "" -}}
      {{- fail (printf "summary Anthropic engine %s requires engines.%s.apiKey or summary.existing.apiKey" $name $name) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.summary.create" -}}
{{- include "groundx.summary.validateAnthropic" . -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $urlEmpty := eq (dig "url" "" $ex) "" -}}
{{- $stype := lower (coalesce (dig "serviceType" "" $ex) "eyelevel") | trim -}}
{{- $svcAllowed := has $stype (list "openai" "openai-base64" "azure" "anthropic") -}}
{{- $engines := .Values.engines | default dict -}}
{{- $anthropicOnly := gt (len $engines) 0 -}}
{{- $anthropicSelected := eq $stype "anthropic" -}}
{{- $localNeeded := false -}}
{{- range $engine := $engines -}}
  {{- $service := coalesce (get $engine "service") (get $engine "serviceType") $stype | default "" | toString | trim -}}
  {{- if eq $service "anthropic" -}}
    {{- $anthropicSelected = true -}}
  {{- end -}}
  {{- if eq $service "eyelevel" -}}
    {{- $localNeeded = true -}}
  {{- end -}}
  {{- if ne $service "anthropic" -}}
    {{- $anthropicOnly = false -}}
  {{- end -}}
{{- end -}}
{{- if and $anthropicSelected $localNeeded -}}
true
{{- else -}}
{{- and $urlEmpty (not $svcAllowed) (not $anthropicOnly) -}}
{{- end -}}
{{- end }}

{{- define "groundx.summary.apiKey" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $stype := lower (coalesce (dig "serviceType" "" $ex) "eyelevel") | trim -}}
{{- if eq $stype "anthropic" -}}
{{ dig "apiKey" "" $ex }}
{{- else -}}
{{- coalesce (dig "apiKey" "" $ex) (include "groundx.admin.apiKey" .) | default "" -}}
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
