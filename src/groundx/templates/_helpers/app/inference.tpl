{{- define "groundx.inference.services" -}}
{{- $svcs := dict -}}
{{- $il := include "groundx.layout.inference.create" . -}}
{{- if eq $il "true" -}}
{{- $_ := set $svcs "layout.inference" "layout.inference" -}}
{{- end -}}
{{- $ir := include "groundx.ranker.inference.create" . -}}
{{- if eq $ir "true" -}}
{{- $_ := set $svcs "ranker.inference" "ranker.inference" -}}
{{- end -}}
{{- $is := include "groundx.summary.create" . -}}
{{- if eq $is "true" -}}
{{- $_ := set $svcs "summary.inference" "summary.inference" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
