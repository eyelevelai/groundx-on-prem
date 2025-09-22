{{- define "groundx.layout.save.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-save" $svc }}
{{- end }}

{{- define "groundx.layout.save.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "save" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.save.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "save" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) (include "groundx.layout.save.serviceName" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.save.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "save" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.save.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "save" nil $b) | default dict -}}
{{ dig "queue" "save_queue" $in }}
{{- end }}

{{- define "groundx.layout.save.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "save" nil $b) | default dict -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.save.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "save" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.save.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "save" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.save.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.save.image" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.save.pull" .) -}}
{{- $_ := set $cfg "queue"        (include "groundx.layout.save.queue" .) -}}
{{- $_ := set $cfg "threads"      (include "groundx.layout.save.threads" .) -}}
{{- $_ := set $cfg "workers"      (include "groundx.layout.save.workers" .) -}}
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
