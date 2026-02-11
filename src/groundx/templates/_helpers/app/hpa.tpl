{{- define "groundx.hpa" -}}

{{- $svcs := dict -}}

{{- $services := list
  "extract.agent"
  "extract.api"
  "extract.download"
  "extract.save"
  "groundx"
  "layout.api"
  "layout.correct"
  "layout.map"
  "layout.ocr"
  "layout.process"
  "layout.save"
  "layoutWebhook"
-}}
{{- $na := list
  "layout.inference"
  "preProcess"
  "process"
  "queue"
  "summaryClient"
  "summary.api"
  "summary.inference"
  "upload"
-}}

{{- range $svc := $services }}
  {{- $tpl := printf "groundx.%s.hpa" $svc -}}
  {{- $gx := include $tpl $ | fromYaml -}}
  {{- $enabled := dig "enabled" "false" $gx | toString -}}
  {{- if eq $enabled "true" -}}
    {{- $_ := set $svcs $svc $svc -}}
  {{- end -}}
{{- end }}

{{- $svcs | toYaml -}}

{{- end }}

{{- define "groundx.hpa.cooldown" -}}
60
{{- end }}
