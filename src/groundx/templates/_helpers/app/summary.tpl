{{- define "groundx.summary.serviceName" -}}
{{- $in := .Values.summary | default dict -}}
{{ dig "serviceName" "summary" $in }}
{{- end }}

{{- define "groundx.summary.existing" -}}
{{- $in := .Values.summary | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $hasService := and (hasKey $ex "serviceType") (ne (get $ex "serviceType" | toString | trim) "") -}}
{{- $hasUrl := and (hasKey $ex "url") (ne (get $ex "url" | toString | trim) "") -}}
{{- if or $hasService $hasUrl -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.summary.create" -}}
{{- $engines := include "groundx.engines" . | fromYaml -}}
{{- $localNeeded := false -}}
{{- range $engine := $engines -}}
  {{- if eq (include "groundx.engine.create" (dict "root" $ "engine" $engine)) "true" -}}
    {{- $localNeeded = true -}}
  {{- end -}}
{{- end -}}
{{- $localNeeded -}}
{{- end }}

{{- define "groundx.summary.model.create" -}}
{{- $create := eq (include "groundx.summary.create" .) "true" -}}
{{- if eq (include "groundx.extract.agent.create" .) "true" -}}
  {{- $engine := include "groundx.extract.agent.engine" . | fromYaml -}}
  {{- $create = or $create (eq (include "groundx.engine.create" (dict "root" . "engine" $engine)) "true") -}}
{{- end -}}
{{- $create -}}
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
