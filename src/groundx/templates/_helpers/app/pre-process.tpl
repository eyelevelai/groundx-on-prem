{{- define "groundx.preProcess.serviceName" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "serviceName" "pre-process" $in }}
{{- end }}

{{- define "groundx.preProcess.queue" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "queue" "file-pre-process" $in }}
{{- end }}

{{- define "groundx.preProcess.create" -}}
{{- $in := .Values.preProcess | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.preProcess.containerPort" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.preProcess.image" -}}
{{- $in := .Values.preProcess.image | default dict -}}
{{- $bs := printf "%s/eyelevel/pre-process" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.preProcess.pull" -}}
{{- $in := .Values.preProcess.image | default dict -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.preProcess.queueSize" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.preProcess.settings" -}}
{{- $in := .Values.preProcess | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.preProcess.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.preProcess.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.preProcess.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.preProcess.pull" .) -}}
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