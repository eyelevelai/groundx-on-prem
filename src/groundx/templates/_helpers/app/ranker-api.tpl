{{- define "groundx.ranker.api.serviceName" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.ranker.api.create" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.containerPort" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.ranker.api.image" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/python-api" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.ranker.api.port" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.pull" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.ranker.api.ssl" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := .Values.ranker.api.loadBalancer | default dict -}}
{{ dig "ssl" "false" $lb  }}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.ranker.serviceName" . -}}
{{- $port := include "groundx.ranker.api.port" . -}}
{{- $ssl := include "groundx.ranker.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.threads" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "threads" 3 $in }}
{{- end }}

{{- define "groundx.ranker.api.timeout" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "timeout" 120 $in }}
{{- end }}

{{- define "groundx.ranker.api.workers" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.ranker.api.loadBalancer" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := (dig "loadBalancer" nil $in) | default dict -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.ranker.api.port" .)
    "ssl"        (dig "ssl" "false" $lb)
    "targetPort" (include "groundx.ranker.api.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- else -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.ranker.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.ranker.api.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.settings" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "api" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "name"         (include "groundx.ranker.api.serviceName" .) -}}
{{- $_ := set $cfg "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc) -}}
{{- $_ := set $cfg "image"        (include "groundx.ranker.api.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.ranker.api.loadBalancer" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.ranker.api.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.ranker.api.pull" .) -}}
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
