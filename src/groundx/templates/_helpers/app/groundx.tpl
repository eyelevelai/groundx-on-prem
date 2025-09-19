{{- define "groundx.groundx.serviceName" -}}
{{- $in := .Values.groundx | default dict -}}
{{ dig "serviceName" "groundx" $in }}
{{- end }}

{{- define "groundx.groundx.create" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.groundx.containerPort" -}}
{{- $in := .Values.groundx | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.groundx.image" -}}
{{- $in := .Values.groundx.image | default dict -}}
{{- $bs := printf "%s/eyelevel/groundx" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.groundx.port" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := .Values.groundx.loadBalancer | default dict -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.groundx.pull" -}}
{{- $in := .Values.groundx.image | default dict -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.groundx.ssl" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := .Values.groundx.loadBalancer | default dict -}}
{{ dig "ssl" "false" $lb  }}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.groundx.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.groundx.serviceName" . -}}
{{- $port := include "groundx.groundx.port" . -}}
{{- $ssl := include "groundx.groundx.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{ printf "%s://%s.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end }}

{{- define "groundx.groundx.type" -}}
{{- $in := .Values.groundx | default dict -}}
{{ (dig "type" "all" $in) }}
{{- end }}

{{- define "groundx.groundx.loadBalancer" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := .Values.groundx.loadBalancer | default dict -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.groundx.port" .)
    "ssl"        (include "groundx.groundx.ssl" .)
    "targetPort" (include "groundx.groundx.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- else -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.groundx.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.groundx.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.groundx.settings" -}}
{{- $in := .Values.groundx | default dict -}}
{{- $cfg := dict
  "dependencies" (dict
    "cache"  "cache"
    "file"   "file"
    "search" "search"
    "db"     "db"
    "stream" "stream"
  )
-}}
{{- $_ := set $cfg "name"         (include "groundx.groundx.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.groundx.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.groundx.loadBalancer" . | trim) -}}
{{- $_ := set $cfg "port"         (include "groundx.groundx.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.groundx.pull" .) -}}
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
