{{- define "groundx.layout.map.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-map" $svc }}
{{- end }}

{{- define "groundx.layout.map.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "map" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.map.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "map" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) (include "groundx.layout.process.serviceName" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.map.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "map" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.map.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "map" nil $b) | default dict -}}
{{ dig "queue" "map_queue" $in }}
{{- end }}

{{- define "groundx.layout.map.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "map" nil $b) | default dict -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.map.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "map" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.map.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "map" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.map.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.map.image" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.map.pull" .) -}}
{{- $_ := set $cfg "queue"        (include "groundx.layout.map.queue" .) -}}
{{- $_ := set $cfg "threads"      (include "groundx.layout.map.threads" .) -}}
{{- $_ := set $cfg "workers"      (include "groundx.layout.map.workers" .) -}}
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
