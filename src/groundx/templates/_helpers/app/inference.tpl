{{- define "groundx.inference.services" -}}
{{- $svcs := dict
  "layout.inference"  "layout.inference"
  "summary.inference" "summary.inference"
-}}
{{- $io := include "groundx.ranker.inference.create" . -}}
{{- if eq $io "true" -}}
{{- $_ := set $svcs "ranker.inference" "ranker.inference" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
