{{- define "groundx.layout.serviceName" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "serviceName" "layout" $in }}
{{- end }}

{{- define "groundx.layout.callbackApiKey" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "callbackApiKey" (include "groundx.admin.username" .) $in }}
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

{{- $svcs := dict -}}

{{- $services := list
  "layout.correct"
  "layout.inference"
  "layout.map"
  "layout.ocr"
  "layout.process"
  "layout.save"
-}}

{{- range $svc := $services }}
  {{- $tpl := printf "groundx.%s.create" $svc -}}
  {{- $il := include $tpl $ -}}
  {{- if eq $il "true" -}}
    {{- $_ := set $svcs $svc $svc -}}
  {{- end -}}
{{- end }}

{{- $svcs | toYaml -}}

{{- end }}

{{- define "groundx.layout.podMemory" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "podMemory" "2Gi" $in }}
{{- end }}
