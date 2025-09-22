{{- define "groundx.inference.services" -}}
{{- $svcs := dict
  "layout.inference"  "layout.inference"
  "ranker.inference"  "ranker.inference"
  "summary.inference" "summary.inference"
-}}
{{- $svcs | toYaml -}}
{{- end }}
