{{- define "groundx.layout.api.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.layout.api.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.containerPort" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layout.api.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/python-api" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.api.port" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.api.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.layout.api.timeout" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "timeout" 120 $in }}
{{- end }}

{{- define "groundx.layout.api.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "workers" 2 $in }}
{{- end }}

{{- define "groundx.layout.api.loadBalancer" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.layout.api.port" .)
    "ssl"        (dig "ssl" "false" $lb)
    "targetPort" (include "groundx.layout.api.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- end -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.layout.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.layout.api.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end }}

{{- define "groundx.layout.api.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.api.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.api.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.layout.api.loadBalancer" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.layout.api.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.api.pull" .) -}}
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
