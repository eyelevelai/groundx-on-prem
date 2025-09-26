{{- define "groundx.summary.api.node" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.summary.api.serviceName" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.summary.api.create" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.containerPort" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summary.api.image" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $img := dig "image" dict $in -}}
{{- $bs := printf "%s/eyelevel/python-api" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.summary.api.isRoute" -}}
{{- $lb := (include "groundx.summary.api.loadBalancer" . | fromYaml) -}}
{{- $os := include "groundx.isOpenshift" . -}}
{{- $ty := (dig "type" "ClusterIP" $lb) | trim | lower -}}
{{- if or (eq $ty "route") (and (eq $ty "loadbalancer") (eq $os "true")) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.port" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "port" 80 $lb }}
{{- end }}

{{- define "groundx.summary.api.pull" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $img := dig "image" dict $in -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.summary.api.replicas" -}}
{{- $b := .Values.summary | default dict -}}
{{- $c := dig "api" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.summary.api.ssl" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "ssl" "false" $lb  }}
{{- end }}

{{- define "groundx.summary.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.summary.serviceName" . -}}
{{- $port := include "groundx.summary.api.port" . -}}
{{- $ssl := include "groundx.summary.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.threads" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "threads" 4 $in }}
{{- end }}

{{- define "groundx.summary.api.timeout" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "timeout" 240 $in }}
{{- end }}

{{- define "groundx.summary.api.workers" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.summary.api.loadBalancer" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
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
{{- $in := dig "api" dict $b -}}
{{- $rep := (include "groundx.summary.api.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "node"     (include "groundx.summary.api.node" .)
  "replicas" ($rep)
-}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "name"         (include "groundx.summary.api.serviceName" .) -}}
{{- $_ := set $cfg "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc) -}}
{{- $_ := set $cfg "image"        (include "groundx.summary.api.image" .) -}}
{{- $_ := set $cfg "isRoute"      (include "groundx.summary.api.isRoute" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.summary.api.loadBalancer" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.summary.api.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.summary.api.pull" .) -}}
{{- if and (hasKey $in "affinity") (not (empty (get $in "affinity"))) -}}
  {{- $_ := set $cfg "affinity" (get $in "affinity") -}}
{{- end -}}
{{- if and (hasKey $in "annotations") (not (empty (get $in "annotations"))) -}}
  {{- $_ := set $cfg "annotations" (get $in "annotations") -}}
{{- end -}}
{{- if and (hasKey $in "containerSecurityContext") (not (empty (get $in "containerSecurityContext"))) -}}
  {{- $_ := set $cfg "containerSecurityContext" (get $in "containerSecurityContext") -}}
{{- end -}}
{{- if and (hasKey $in "labels") (not (empty (get $in "labels"))) -}}
  {{- $_ := set $cfg "labels" (get $in "labels") -}}
{{- end -}}
{{- if and (hasKey $in "nodeSelector") (not (empty (get $in "nodeSelector"))) -}}
  {{- $_ := set $cfg "nodeSelector" (get $in "nodeSelector") -}}
{{- end -}}
{{- if and (hasKey $in "resources") (not (empty (get $in "resources"))) -}}
  {{- $_ := set $cfg "resources" (get $in "resources") -}}
{{- end -}}
{{- if and (hasKey $in "securityContext") (not (empty (get $in "securityContext"))) -}}
  {{- $_ := set $cfg "securityContext" (get $in "securityContext") -}}
{{- end -}}
{{- if and (hasKey $in "tolerations") (not (empty (get $in "tolerations"))) -}}
  {{- $_ := set $cfg "tolerations" (get $in "tolerations") -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}
