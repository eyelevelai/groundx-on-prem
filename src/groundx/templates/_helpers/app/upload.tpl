{{- define "groundx.upload.serviceName" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "serviceName" "upload" $in }}
{{- end }}

{{- define "groundx.upload.queue" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "queue" "file-upload" $in }}
{{- end }}

{{- define "groundx.upload.create" -}}
{{- $in := .Values.upload | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.upload.containerPort" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.upload.image" -}}
{{- $in := .Values.upload.image | default dict -}}
{{- $bs := printf "%s/eyelevel/upload" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.upload.pull" -}}
{{- $in := .Values.upload.image | default dict -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.upload.queueSize" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.upload.settings" -}}
{{- $in := .Values.upload | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.upload.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.upload.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.upload.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.upload.pull" .) -}}
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