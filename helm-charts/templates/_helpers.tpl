{{- define "groundx.ns" -}}
{{- if .Values.namespace -}}
{{ .Values.namespace }}
{{- else -}}
{{ .Release.Namespace }}
{{- end -}}
{{- end }}