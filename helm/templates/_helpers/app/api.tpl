{{- define "groundx.api.services" -}}
{{- $svcs := dict -}}
{{- $il := include "groundx.layout.api.create" . -}}
{{- if eq $il "true" -}}
{{- $_ := set $svcs "layout.api" "layout.api" -}}
{{- end -}}
{{- $ir := include "groundx.ranker.api.create" . -}}
{{- if eq $ir "true" -}}
{{- $_ := set $svcs "ranker.api" "ranker.api" -}}
{{- end -}}
{{- $is := include "groundx.summary.api.create" . -}}
{{- if eq $is "true" -}}
{{- $_ := set $svcs "summary.api" "summary.api" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
