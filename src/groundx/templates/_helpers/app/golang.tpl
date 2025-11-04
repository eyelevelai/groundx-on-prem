{{- define "groundx.golang.username" -}}
{{- $in := .Values.golang | default dict -}}
{{- if hasKey $in "username" -}}
{{ (dig "username" "golang" $in) }}
{{- else if eq .Values.imageType "chainguard" -}}
nonroot
{{- else -}}
golang
{{- end -}}
{{- end }}

{{- define "groundx.integration.search.duration" -}}
{{- $b := .Values.integration | default dict -}}
{{- $in := (dig "search" nil $b) | default dict -}}
{{ dig "duration" 3660 $in }}
{{- end }}

{{- define "groundx.integration.search.fileId" -}}
{{- $b := .Values.integration | default dict -}}
{{- $in := (dig "search" nil $b) | default dict -}}
{{ dig "fileId" "ey-mtr6hapxq7d94zigammwir6xz4" $in }}
{{- end }}

{{- define "groundx.integration.search.modelId" -}}
{{- $b := .Values.integration | default dict -}}
{{- $in := (dig "search" nil $b) | default dict -}}
{{ dig "modelId" 1 $in }}
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
