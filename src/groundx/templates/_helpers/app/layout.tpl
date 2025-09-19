{{- define "groundx.layout.process.services" -}}
{{- $svcs := dict
  "layout.correct" "layout.correct"
  "layout.map"     "layout.map"
  "layout.ocr"     "layout.ocr"
  "layout.process" "layout.process"
  "layout.save"    "layout.save"
-}}
{{- $svcs | toYaml -}}
{{- end }}

{{- define "groundx.layout.serviceName" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "layout" "layout" $in }}
{{- end }}
