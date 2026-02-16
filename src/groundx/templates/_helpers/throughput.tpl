{{- define "groundx.throughput.tpm.document" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "tpm" nil $b) | default dict -}}
{{ dig "document" 12500 $in }}
{{- end }}

{{- define "groundx.throughput.tpm.page" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "tpm" nil $b) | default dict -}}
{{ dig "page" 500 $in }}
{{- end }}

{{- define "groundx.throughput.tpm.summaryRequest" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "tpm" nil $b) | default dict -}}
{{ dig "summaryRequest" 625 $in }}
{{- end }}
