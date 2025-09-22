{{- define "groundx.summary.api.serviceName" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.summary.api.create" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.containerPort" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summary.api.image" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/python-api" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.summary.api.port" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.pull" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.summary.api.threads" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "threads" 4 $in }}
{{- end }}

{{- define "groundx.summary.api.timeout" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "timeout" 240 $in }}
{{- end }}

{{- define "groundx.summary.api.workers" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.summary.api.loadBalancer" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.summary.api.port" .)
    "ssl"        (dig "ssl" "false" $lb)
    "targetPort" (include "groundx.summary.api.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- else -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.summary.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.summary.api.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.settings" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "name"         (include "groundx.summary.api.serviceName" .) -}}
{{- $_ := set $cfg "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc) -}}
{{- $_ := set $cfg "image"        (include "groundx.summary.api.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.summary.api.loadBalancer" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.summary.api.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.summary.api.pull" .) -}}
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
