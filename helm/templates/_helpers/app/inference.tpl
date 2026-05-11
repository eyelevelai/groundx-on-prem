{{- define "groundx.inference.services" -}}

{{- $svcs := dict -}}

{{- $services := list
  "layout.inference"
  "ranker.inference"
  "summary.inference"
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
