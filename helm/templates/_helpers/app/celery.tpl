{{- define "groundx.celery.process.services" -}}
{{- $svcs := dict -}}
{{- $services := list
  "extract.agent"
  "extract.download"
  "extract.save"
  "layout.correct"
  "layout.map"
  "layout.ocr"
  "layout.process"
  "layout.save"
-}}
{{- range $svc := $services }}
  {{- $tpl := printf "groundx.%s.create" $svc -}}
  {{- $il := include $tpl $ -}}
  {{- if eq $il "true" -}}
    {{- $_ := set $svcs $svc $svc -}}
  {{- end -}}
{{- end }}
{{- $svcs | toYaml -}}
{{- end }}

{{- define "groundx.celery.options" -}}
{{- $ty := include "groundx.cache.type" . -}}
{{- if eq $ty "valkey" -}}
 --without-gossip --without-mingle --without-heartbeat
{{- else -}}
{{- end -}}
{{- end }}

{{- define "groundx.celery.env" -}}
{{- $ty := include "groundx.cache.type" . -}}
{{- if eq $ty "valkey" -}}
,CELERY_WORKER_ENABLE_REMOTE_CONTROL="false",CELERY_WORKER_SEND_TASK_EVENTS="false",CELERY_TASK_SEND_SENT_EVENT="false"
{{- else -}}
{{- end -}}
{{- end }}
