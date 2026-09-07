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
{{- $engines := include "groundx.engines" . | fromYaml -}}
{{- $localUrl := include "groundx.summary.api.serviceUrl" . | trim -}}
{{- $localNeeded := false -}}
{{- range $engine := $engines -}}
  {{- if and (eq (get $engine "service") "eyelevel") (eq (get $engine "baseUrl" | default "" | toString | trim) $localUrl) -}}
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
{{- $engines := include "groundx.engines" . | fromYaml -}}
{{- $engine := get $engines "default" | default dict -}}
{{- get $engine "apiKey" | default "" -}}
{{- end }}

{{- define "groundx.summary.baseUrl" -}}
{{- $engines := include "groundx.engines" . | fromYaml -}}
{{- $engine := get $engines "default" | default dict -}}
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
