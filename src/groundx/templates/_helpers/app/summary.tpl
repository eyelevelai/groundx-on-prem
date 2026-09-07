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

{{- define "groundx.summary.defaultEngine.resolved" -}}
{{- $engines := include "groundx.engines" . | fromYaml -}}
{{- $engine := get $engines "default" | default dict -}}
{{- $summary := .Values.summary | default dict -}}
{{- $existing := dig "existing" dict $summary -}}
{{- $existingConfigured := eq (include "groundx.summary.existingConfigured" .) "true" -}}
{{- $explicitService := coalesce (get $engine "service") (get $engine "serviceType") "" | default "" | toString | lower | trim -}}
{{- $service := coalesce $explicitService (include "groundx.summary.serviceType" .) | default "eyelevel" | toString | lower | trim -}}
{{- $engineBaseUrl := get $engine "baseUrl" | default "" | toString | trim -}}
{{- $local := and (eq $service "eyelevel") (eq $engineBaseUrl "") (or (not $existingConfigured) (eq $explicitService "eyelevel")) -}}
{{- $baseUrl := "" -}}
{{- if ne $engineBaseUrl "" -}}
  {{- $baseUrl = get $engine "baseUrl" -}}
{{- else if $local -}}
  {{- $baseUrl = include "groundx.summary.api.serviceUrl" . | trim -}}
{{- else if ne (dig "url" "" $existing | toString | trim) "" -}}
  {{- $baseUrl = get $existing "url" -}}
{{- end -}}
{{- $resolved := dict
  "baseUrl" $baseUrl
  "local" $local
  "modelId" (get $engine "engineId" | default "")
  "service" $service
-}}
{{- if hasKey $engine "apiKey" -}}
  {{- $_ := set $resolved "apiKey" (get $engine "apiKey") -}}
{{- else if hasKey $existing "apiKey" -}}
  {{- $_ := set $resolved "apiKey" (get $existing "apiKey") -}}
{{- else if $local -}}
  {{- $_ := set $resolved "apiKey" (include "groundx.admin.apiKey" .) -}}
{{- end -}}
{{- if hasKey $engine "reasoningEffort" -}}
  {{- $_ := set $resolved "reasoningEffort" (get $engine "reasoningEffort") -}}
{{- end -}}
{{- $resolved | toYaml -}}
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
  {{- $explicitService := coalesce (get $engine "service") (get $engine "serviceType") "" | default "" | toString | lower | trim -}}
  {{- $service := coalesce $explicitService $stype | default "eyelevel" | toString | lower | trim -}}
  {{- $hasBaseUrl := and (hasKey $engine "baseUrl") (ne (get $engine "baseUrl" | toString | trim) "") -}}
  {{- if and (eq $service "eyelevel") (not $hasBaseUrl) (or (not $existingConfigured) (eq $explicitService "eyelevel")) -}}
    {{- $localNeeded = true -}}
  {{- end -}}
{{- end -}}
{{- $localNeeded -}}
{{- end }}

{{- define "groundx.summary.workloads.create" -}}
{{- $summaryNeedsLocal := eq (include "groundx.summary.create" .) "true" -}}
{{- $extractNeedsLocal := eq (include "groundx.extract.agent.localModel" .) "true" -}}
{{- if or $summaryNeedsLocal $extractNeedsLocal -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.summary.apiKey" -}}
{{- $engine := include "groundx.summary.defaultEngine.resolved" . | fromYaml -}}
{{- get $engine "apiKey" | default "" -}}
{{- end }}

{{- define "groundx.summary.baseUrl" -}}
{{- $engine := include "groundx.summary.defaultEngine.resolved" . | fromYaml -}}
{{- get $engine "baseUrl" | default "" -}}
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
