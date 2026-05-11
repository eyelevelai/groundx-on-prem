{{- define "groundx.engines" -}}
{{- $in := .Values.engines | default list -}}
{{- if gt (len $in) 0 }}
{{- $in | toYaml -}}
{{- else -}}
{{- $replicas := (include "groundx.summary.inference.replicas" . | fromYaml) -}}
{{- $desired := get $replicas "desired" -}}
{{- $scaled := mul $desired 2 -}}
{{- $eng := dict
  "dataType"        (include "groundx.summary.inference.model.dataType" .)
  "engineId"        (include "groundx.summary.inference.model.name" .)
  "maxInputTokens"  (include "groundx.summary.inference.model.maxInputTokens" .)
  "maxOutputTokens" (include "groundx.summary.inference.model.maxOutputTokens" .)
  "maxRequests"     ($scaled)
  "requestLimit"    ($scaled)
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
