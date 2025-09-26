{{- define "groundx.layoutWebhook.node" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

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
{{- $b := .Values.layoutWebhook | default dict -}}
{{- $in := dig "image" dict $b -}}
{{- $bs := printf "%s/eyelevel/layout-webhook" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.layoutWebhook.isRoute" -}}
{{- $lb := (include "groundx.layoutWebhook.loadBalancer" . | fromYaml) -}}
{{- $os := include "groundx.isOpenshift" . -}}
{{- $ty := (dig "type" "ClusterIP" $lb) | trim | lower -}}
{{- if or (eq $ty "route") (and (eq $ty "loadbalancer") (eq $os "true")) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.port" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "port" 80 $lb }}
{{- end }}

{{- define "groundx.layoutWebhook.pull" -}}
{{- $b := .Values.layoutWebhook | default dict -}}
{{- $in := dig "image" dict $b -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.layoutWebhook.replicas" -}}
{{- $b := .Values.layoutWebhook | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layoutWebhook.ssl" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "ssl" "false" $lb  }}
{{- end }}

{{- define "groundx.layoutWebhook.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.layoutWebhook.serviceName" . -}}
{{- $port := include "groundx.layoutWebhook.port" . -}}
{{- $ssl := include "groundx.layoutWebhook.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.loadBalancer" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.layoutWebhook.port" .)
    "ssl"        (dig "ssl" "false" $lb)
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
{{- $rep := (include "groundx.layoutWebhook.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "isRoute"      (include "groundx.layoutWebhook.isRoute" .)
  "node"         (include "groundx.layoutWebhook.node" .)
  "replicas"     ($rep)
-}}
{{- $_ := set $cfg "name"         (include "groundx.layoutWebhook.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layoutWebhook.image" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.layoutWebhook.loadBalancer" . | trim) -}}
{{- $_ := set $cfg "port"         (include "groundx.layoutWebhook.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layoutWebhook.pull" .) -}}
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
