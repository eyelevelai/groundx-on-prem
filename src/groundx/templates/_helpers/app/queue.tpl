{{- define "groundx.queue.serviceName" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "serviceName" "queue" $in }}
{{- end }}

{{- define "groundx.queue.queue" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "queue" "file-update" $in }}
{{- end }}

{{- define "groundx.queue.create" -}}
{{- $in := .Values.queue | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.queue.containerPort" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.queue.image" -}}
{{- $in := .Values.queue.image | default dict -}}
{{- $bs := printf "%s/eyelevel/queue" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.queue.pull" -}}
{{- $in := .Values.queue.image | default dict -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.queue.queueSize" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.queue.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.queue.serviceName" . -}}
{{- $port := include "groundx.queue.containerPort" . -}}
{{- if eq $port "80" -}}
{{ printf "http://%s.%s.svc.cluster.local" $name $ns }}
{{- else -}}
{{ printf "http://%s.%s.svc.cluster.local:%v" $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.queue.settings" -}}
{{- $in := .Values.queue | default dict -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
-}}
{{- $_ := set $cfg "name"         (include "groundx.queue.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.queue.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.queue.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.queue.pull" .) -}}
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
