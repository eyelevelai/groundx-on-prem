{{- define "groundx.defaultEngine" -}}
google/gemma-3-4b-it
{{- end }}

{{- define "groundx.defaultDataType" -}}
bfloat16
{{- end }}

{{- define "groundx.engines" -}}
{{- $in := .Values.engines | default list -}}
{{- if gt (len $in) 0 }}
{{- $in | toYaml -}}
{{- else -}}
{{- $eng := dict
  "dataType"        (include "groundx.defaultDataType" .)
  "engineId"        (include "groundx.defaultEngine" .)
  "maxInputTokens"  (100000)
  "maxOutputTokens" (2000)
  "maxRequests"     (4)
  "requestLimit"    (4)
  "vision"          (true)
-}}
{{- dict "default" $eng | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.hasCustomEngines" -}}
{{- $in := .Values.engines | default list -}}
{{- if gt (len $in) 0 }}
true
{{- else -}}
false
{{- end -}}
{{- end }}
