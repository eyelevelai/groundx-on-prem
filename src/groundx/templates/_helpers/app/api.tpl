{{- define "groundx.api.services" -}}
{{- $svcs := dict
  "layout.api" "layout.api"
-}}
{{- $svcs | toYaml -}}
{{- end }}
