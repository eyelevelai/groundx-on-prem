{{- define "groundx.app.ingress" -}}

{{- $svcs := dict -}}

{{ $gx := include "groundx.groundx.ingress" . | fromYaml }}
{{- $gxe := dig "enabled" "true" $gx | toString -}}
{{- if eq $gxe "true" -}}
{{- $_ := set $svcs "groundx" "groundx" -}}
{{- end -}}

{{- $services := list
  "file"
  "extract.api"
  "layout.api"
  "layoutWebhook"
  "ranker.api"
  "summary.api"
-}}

{{- range $svc := $services }}
  {{- $tpl := printf "groundx.%s.ingress" $svc -}}
  {{- $gx := include $tpl $ | fromYaml -}}
  {{- $enabled := dig "enabled" "false" $gx | toString -}}
  {{- if eq $enabled "true" -}}
    {{- $_ := set $svcs $svc $svc -}}
  {{- end -}}
{{- end }}

{{- $svcs | toYaml -}}

{{- end }}
