{{- define "groundx.ranker.serviceName" -}}
{{- $in := .Values.ranker | default dict -}}
{{ dig "serviceName" "ranker" $in }}
{{- end }}
