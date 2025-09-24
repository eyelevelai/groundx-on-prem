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

{{- define "groundx.layout.hasOCRCredentials" -}}
{{- $path := include "groundx.layout.ocr.credentials" . -}}
{{- if and (kindIs "string" $path) (ne $path "") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.layout.supervisor" -}}
{{- $svcs := dict
  "correct"   "layout.correct"
  "inference" "layout.inference"
  "map"       "layout.map"
  "ocr"       "layout.ocr"
  "process"   "layout.process"
  "save"      "layout.save"
-}}
{{- $svcs | toYaml -}}
{{- end }}

{{- define "groundx.layout.serviceName" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "serviceName" "layout" $in }}
{{- end }}

{{- define "groundx.layout.podMemory" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "podMemory" "2Gi" $in }}
{{- end }}