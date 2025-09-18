{{- define "groundx.summaryClient.serviceName" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "serviceName" "summary-client" $in }}
{{- end }}

{{- define "groundx.summaryClient.queue" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "queue" "file-summary" $in }}
{{- end }}

{{- define "groundx.summaryClient.create" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.summaryClient.containerPort" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summaryClient.image" -}}
{{- $in := .Values.summaryClient.image | default dict -}}
{{- $bs := printf "%s/eyelevel/summary-client" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.summaryClient.pull" -}}
{{- $in := .Values.summaryClient.image | default dict -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.summaryClient.queueSize" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "queueSize" 3 $in }}
{{- end }}

{{- define "groundx.summaryClient.settings" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.summaryClient.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.summaryClient.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.summaryClient.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.summaryClient.pull" .) -}}
{{- if and (hasKey $in "replicas") (not (empty (get $in "replicas"))) -}}
  {{- $_ := set $cfg "replicas" (get $in "replicas") -}}
{{- end -}}
{{- if and (hasKey $in "resources") (not (empty (get $in "resources"))) -}}
  {{- $_ := set $cfg "resources" (get $in "resources") -}}
{{- end -}}
{{- if and (hasKey $in "securityContext") (not (empty (get $in "securityContext"))) -}}
  {{- $_ := set $cfg "securityContext" (get $in "securityContext") -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}