{{- define "groundx.api.services" -}}
{{- $svcs := dict
  "layout.api"  "layout.api"
  "ranker.api"  "ranker.api"
  "summary.api" "summary.api"
-}}
{{- $svcs | toYaml -}}
{{- end }}
