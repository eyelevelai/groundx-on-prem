{{- define "groundx.process.serviceName" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "serviceName" "process" $in }}
{{- end }}

{{- define "groundx.process.queue" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "queue" "file-process" $in }}
{{- end }}

{{- define "groundx.process.create" -}}
{{- $in := .Values.process | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.process.containerPort" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.process.image" -}}
{{- $in := .Values.process.image | default dict -}}
{{- $bs := printf "%s/eyelevel/process" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.process.pull" -}}
{{- $in := .Values.process.image | default dict -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.process.queueSize" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.process.settings" -}}
{{- $in := .Values.process | default dict -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
-}}
{{- $_ := set $cfg "name"         (include "groundx.process.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.process.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.process.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.process.pull" .) -}}
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
