{{- define "groundx.layoutWebhook.serviceName" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "serviceName" "layout-webhook" $in }}
{{- end }}

{{- define "groundx.layoutWebhook.create" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.containerPort" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layoutWebhook.image" -}}
{{- $in := .Values.layoutWebhook.image | default dict -}}
{{- $bs := printf "%s/eyelevel/layout-webhook" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.layoutWebhook.port" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := .Values.layoutWebhook.loadBalancer | default dict -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.pull" -}}
{{- $in := .Values.layoutWebhook.image | default dict -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.layoutWebhook.ssl" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := .Values.layoutWebhook.loadBalancer | default dict -}}
{{ dig "ssl" "false" $lb  }}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.loadBalancer" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := .Values.layoutWebhook.loadBalancer | default dict -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.layoutWebhook.port" .)
    "ssl"        (include "groundx.layoutWebhook.ssl" .)
    "targetPort" (include "groundx.layoutWebhook.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- end -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.layoutWebhook.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.layoutWebhook.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end }}

{{- define "groundx.layoutWebhook.settings" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.layoutWebhook.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layoutWebhook.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.layoutWebhook.loadBalancer" . | trim) -}}
{{- $_ := set $cfg "port"         (include "groundx.layoutWebhook.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layoutWebhook.pull" .) -}}
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