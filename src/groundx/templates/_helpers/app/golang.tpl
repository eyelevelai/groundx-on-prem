{{- define "groundx.golang.username" -}}
{{- $in := .Values.golang | default dict -}}
{{- if hasKey $in "username" -}}
{{ (dig "pull" "Always" $in) }}
{{- else if eq .Values.cluster.deployment "chainguard" -}}
nonroot
{{- else -}}
golang
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.create" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.preProcess.create" -}}
{{- $in := .Values.preProcess | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.process.create" -}}
{{- $in := .Values.process | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.queue.create" -}}
{{- $in := .Values.queue | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.summaryClient.create" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.upload.create" -}}
{{- $in := .Values.upload | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.containerPort" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.preProcess.containerPort" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.process.containerPort" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.queue.containerPort" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summaryClient.containerPort" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.upload.containerPort" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layoutWebhook.serviceName" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "serviceName" "layout-webhook" $in }}
{{- end }}

{{- define "groundx.preProcess.serviceName" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "serviceName" "pre-process" $in }}
{{- end }}

{{- define "groundx.process.serviceName" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "serviceName" "process" $in }}
{{- end }}

{{- define "groundx.queue.serviceName" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "serviceName" "queue" $in }}
{{- end }}

{{- define "groundx.summaryClient.serviceName" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "serviceName" "summary-client" $in }}
{{- end }}

{{- define "groundx.upload.serviceName" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "serviceName" "upload" $in }}
{{- end }}

{{- define "groundx.golang.services" -}}
{{- $svcs := dict -}}
{{- if eq (include "groundx.groundx.create" . | trim) "true" -}}
{{- $svcs  = set $svcs "groundx" "groundx" -}}
{{- end -}}
{{- if eq (include "groundx.layoutWebhook.create" . | trim) "true" -}}
{{- $svcs  = set $svcs "layoutWebhook" "layoutWebhook" -}}
{{- end -}}
{{- if eq (include "groundx.preProcess.create" . | trim) "true" -}}
{{- $svcs  = set $svcs "preProcess" "preProcess" -}}
{{- end -}}
{{- if eq (include "groundx.process.create" . | trim) "true" -}}
{{- $svcs  = set $svcs "process" "process" -}}
{{- end -}}
{{- if eq (include "groundx.queue.create" . | trim) "true" -}}
{{- $svcs  = set $svcs "queue" "queue" -}}
{{- end -}}
{{- if eq (include "groundx.summaryClient.create" . | trim) "true" -}}
{{- $svcs  = set $svcs "summaryClient" "summaryClient" -}}
{{- end -}}
{{- if eq (include "groundx.upload.create" . | trim) "true" -}}
{{- $svcs  = set $svcs "upload" "upload" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
