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
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-webhook:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layoutWebhook.imagePullPolicy" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
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
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.replicas" -}}
{{- $b := .Values.layoutWebhook | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layoutWebhook.serviceAccountName" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
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

{{- define "groundx.layoutWebhook.ssl" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "ssl" "false" $lb  }}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.loadBalancer" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
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
{{- $rep := (include "groundx.layoutWebhook.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layoutWebhook.serviceAccountName" . -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "image"        (include "groundx.layoutWebhook.image" .)
  "isRoute"      (include "groundx.layoutWebhook.isRoute" .)
  "loadBalancer" (include "groundx.layoutWebhook.loadBalancer" . | trim)
  "name"         (include "groundx.layoutWebhook.serviceName" .)
  "node"         (include "groundx.layoutWebhook.node" .)
  "port"         (include "groundx.layoutWebhook.containerPort" .)
  "pull"         (include "groundx.layoutWebhook.imagePullPolicy" .)
  "replicas"     ($rep)
-}}
{{- if and $san (ne $san "") -}}
  {{- $_ := set $cfg "serviceAccountName" $san -}}
{{- end -}}
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
