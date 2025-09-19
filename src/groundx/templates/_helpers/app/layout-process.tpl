{{- define "groundx.layout.process.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-process" $svc }}
{{- end }}

{{- define "groundx.layout.process.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.process.batchSize" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{ dig "batchSize" 40 $in }}
{{- end }}

{{- define "groundx.layout.process.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) (include "groundx.layout.process.serviceName" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.process.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.process.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{ dig "queue" "process_queue" $in }}
{{- end }}

{{- define "groundx.layout.process.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.process.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.process.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "process" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.process.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.process.image" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.process.pull" .) -}}
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
