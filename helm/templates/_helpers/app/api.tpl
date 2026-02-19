{{- define "groundx.api.services" -}}

{{- $svcs := dict -}}

{{- $services := list
  "extract.api"
  "layout.api"
  "ranker.api"
  "summary.api"
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
