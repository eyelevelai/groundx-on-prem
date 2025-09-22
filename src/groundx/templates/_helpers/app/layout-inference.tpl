{{- define "groundx.layout.inference.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.layout.inference.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.containerPort" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layout.inference.deviceType" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.layout.inference.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $svc := include "groundx.layout.inference.serviceName" . -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) $svc -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.inference.port" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.inference.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ (dig "queue" "layout_queue" $in) }}
{{- end }}

{{- define "groundx.layout.inference.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "threads" 6 $in }}
{{- end }}

{{- define "groundx.layout.inference.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.inference.loadBalancer" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.layout.inference.port" .)
    "ssl"        (dig "ssl" "false" $lb)
    "targetPort" (include "groundx.layout.inference.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- else -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.layout.inference.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.layout.inference.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.settings" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "baseName"     ($svc) -}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "execOpts"     ("python /app/init-layout.py &&") -}}
{{- $_ := set $cfg "fileSync"     ("true") -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.inference.serviceName" .) -}}
{{- $_ := set $cfg "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.inference.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.layout.inference.loadBalancer" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.layout.inference.containerPort" .) -}}
{{- $_ := set $cfg "workingDir"   ("/app") -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.inference.pull" .) -}}
{{- $_ := set $cfg "queue"        (include "groundx.layout.inference.queue" .) -}}
{{- $_ := set $cfg "threads"      (include "groundx.layout.inference.threads" .) -}}
{{- $_ := set $cfg "workers"      (include "groundx.layout.inference.workers" .) -}}
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
