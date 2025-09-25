{{- define "groundx.layout.inference.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $df := include "groundx.node.gpuLayout" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.inference.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.layout.inference.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.containerPort" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layout.inference.deviceType" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.layout.inference.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $svc := include "groundx.layout.inference.serviceName" . -}}
{{- $in := dig "inference" dict $b -}}
{{- $img := dig "image" dict $in -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) $svc -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.inference.port" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $img := dig "image" dict $in -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.inference.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "queue" "layout_queue" $in) }}
{{- end }}

{{- define "groundx.layout.inference.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "inference" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.inference.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "threads" 6 $in }}
{{- end }}

{{- define "groundx.layout.inference.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.inference.loadBalancer" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
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
{{- $in := dig "inference" dict $b -}}
{{- $rep := (include "groundx.layout.inference.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "node"     (include "groundx.layout.inference.node" .)
  "replicas" ($rep)
-}}
{{- $_ := set $cfg "baseName"     ($svc) -}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "execOpts"     ("python /app/init-layout.py &&") -}}
{{- $_ := set $cfg "fileSync"     ("true") -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.inference.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.inference.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.layout.inference.loadBalancer" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.layout.inference.containerPort" .) -}}
{{- $_ := set $cfg "supervisord"  (printf "%s-inference-supervisord-conf-map" $svc) -}}
{{- $_ := set $cfg "workingDir"   ("/app") -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.inference.pull" .) -}}
{{- $_ := set $cfg "queue"        (include "groundx.layout.inference.queue" .) -}}
{{- $_ := set $cfg "threads"      (include "groundx.layout.inference.threads" .) -}}
{{- $_ := set $cfg "workers"      (include "groundx.layout.inference.workers" .) -}}
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
