{{- define "groundx.layout.correct.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-correct" $svc }}
{{- end }}

{{- define "groundx.layout.correct.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "correct" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.correct.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "correct" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) (include "groundx.layout.correct.serviceName" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.correct.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "correct" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.correct.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "correct" nil $b) | default dict -}}
{{ dig "queue" "correct_queue" $in }}
{{- end }}

{{- define "groundx.layout.correct.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "correct" nil $b) | default dict -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.correct.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "correct" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.correct.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "correct" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.correct.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.correct.image" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.correct.pull" .) -}}
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
