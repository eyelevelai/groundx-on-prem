{{- define "groundx.layout.serviceName" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "serviceName" "layout" $in }}
{{- end }}

{{- define "groundx.layout.callbackApiKey" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "callbackApiKey" (include "groundx.admin.username" .) $in }}
{{- end }}

{{- define "groundx.layout.hasOCRCredentials" -}}
{{- $path := include "groundx.layout.ocr.credentials" . -}}
{{- if and (kindIs "string" $path) (ne $path "") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.layout.supervisor" -}}
{{- $svcs := dict -}}
{{- $ic := include "groundx.layout.correct.create" . -}}
{{- if eq $ic "true" -}}
{{- $_ := set $svcs "layout.correct" "layout.correct" -}}
{{- end -}}
{{- $ii := include "groundx.layout.inference.create" . -}}
{{- if eq $ii "true" -}}
{{- $_ := set $svcs "layout.inference" "layout.inference" -}}
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

{{- define "groundx.layout.podMemory" -}}
{{- $in := .Values.layout | default dict -}}
{{ dig "podMemory" "2Gi" $in }}
{{- end }}