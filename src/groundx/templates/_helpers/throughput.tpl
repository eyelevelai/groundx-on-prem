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

{{- define "groundx.throughput.services.layout.inference" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "services" nil $b) | default dict -}}
{{- $svc := (dig "layout" nil $in) | default dict -}}
{{ dig "inference" 120000 $svc }}
{{- end }}

{{- define "groundx.throughput.services.preProcess.queue" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "services" nil $b) | default dict -}}
{{- $svc := (dig "preProcess" nil $in) | default dict -}}
{{ dig "queue" 6 $svc }}
{{- end }}

{{- define "groundx.throughput.services.process.queue" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "services" nil $b) | default dict -}}
{{- $svc := (dig "process" nil $in) | default dict -}}
{{ dig "queue" 9 $svc }}
{{- end }}

{{- define "groundx.throughput.services.queue.queue" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "services" nil $b) | default dict -}}
{{- $svc := (dig "queue" nil $in) | default dict -}}
{{ dig "queue" 9 $svc }}
{{- end }}

{{- define "groundx.throughput.services.summary.inference" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "services" nil $b) | default dict -}}
{{- $svc := (dig "summary" nil $in) | default dict -}}
{{ dig "inference" 3200 $svc }}
{{- end }}

{{- define "groundx.throughput.services.summaryClient.api" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "services" nil $b) | default dict -}}
{{- $svc := (dig "summaryClient" nil $in) | default dict -}}
{{ dig "api" 9600 $svc }}
{{- end }}

{{- define "groundx.throughput.services.upload.queue" -}}
{{- $b := .Values.throughput | default dict -}}
{{- $in := (dig "services" nil $b) | default dict -}}
{{- $svc := (dig "upload" nil $in) | default dict -}}
{{ dig "queue" 120 $svc }}
{{- end }}
