{{- define "groundx.celery.process.services" -}}
{{- $svcs := dict -}}
{{- $ea := include "groundx.extract.agent.create" . -}}
{{- if eq $ea "true" -}}
{{- $_ := set $svcs "extract.agent" "extract.agent" -}}
{{- end -}}
{{- $ed := include "groundx.extract.download.create" . -}}
{{- if eq $ed "true" -}}
{{- $_ := set $svcs "extract.download" "extract.download" -}}
{{- end -}}
{{- $es := include "groundx.extract.save.create" . -}}
{{- if eq $es "true" -}}
{{- $_ := set $svcs "extract.save" "extract.save" -}}
{{- end -}}
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
