{{- define "groundx.engines" -}}
{{- $in := .Values.engines | default list -}}
{{- if gt (len $in) 0 }}
{{- $in | toYaml -}}
{{- else -}}
{{- $eng := dict
  "dataType"        ("bfloat16")
  "engineID"        ("google/gemma-3-4b-it")
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
