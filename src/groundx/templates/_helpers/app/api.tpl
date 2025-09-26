{{- define "groundx.api.services" -}}
{{- $svcs := dict
  "layout.api"  "layout.api"
  "summary.api" "summary.api"
-}}
{{- $io := include "groundx.ranker.api.create" . -}}
{{- if eq $io "true" -}}
{{- $_ := set $svcs "ranker.api" "ranker.api" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
