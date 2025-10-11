{{- define "groundx.celery.process.services" -}}
{{- $svcs := dict -}}
{{- $ic := include "groundx.layout.correct.create" . -}}
{{- if eq $ic "true" -}}
{{- $_ := set $svcs "layout.correct" "layout.correct" -}}
{{- end -}}
{{- $im := include "groundx.layout.map.create" . -}}
{{- if eq $im "true" -}}
{{- $_ := set $svcs "layout.map" "layout.map" -}}
{{- end -}}
{{- $io := include "groundx.layout.ocr.create" . -}}
{{- if eq $io "true" -}}
{{- $_ := set $svcs "layout.ocr" "layout.ocr" -}}
{{- end -}}
{{- $ip := include "groundx.layout.process.create" . -}}
{{- if eq $ip "true" -}}
{{- $_ := set $svcs "layout.process" "layout.process" -}}
{{- end -}}
{{- $is := include "groundx.layout.save.create" . -}}
{{- if eq $is "true" -}}
{{- $_ := set $svcs "layout.save" "layout.save" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
