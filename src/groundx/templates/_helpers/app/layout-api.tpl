{{- define "groundx.layout.api.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.api.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.layout.api.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.containerPort" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layout.api.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/python-api:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.api.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
{{- end }}

{{- define "groundx.layout.api.isRoute" -}}
{{- $lb := (include "groundx.layout.api.loadBalancer" . | fromYaml) -}}
{{- $os := include "groundx.isOpenshift" . -}}
{{- $ty := (dig "ipType" "ClusterIP" $lb) | trim | lower -}}
{{- if or (eq $ty "route") (and (eq $ty "loadbalancer") (eq $os "true")) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.port" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "api" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.api.ssl" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "ssl" "false" $lb  }}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.layout.serviceName" . -}}
{{- $port := include "groundx.layout.api.port" . -}}
{{- $ssl := include "groundx.layout.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.layout.api.timeout" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "timeout" 120 $in }}
{{- end }}

{{- define "groundx.layout.api.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "workers" 2 $in }}
{{- end }}

{{- define "groundx.layout.api.loadBalancer" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- $name := dig "name" "" $lb -}}
{{- $lbDict := dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.layout.api.port" .)
    "ssl"        (dig "ssl" "false" $lb)
    "targetPort" (include "groundx.layout.api.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "ipType" "ClusterIP" $lb)
-}}
{{- if ne $name "" -}}
  {{- $_ := set $lbDict "name" $name -}}
{{- end -}}
{{- $lbDict | toYaml -}}
{{- else }}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.layout.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.layout.api.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.settings" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $rep := (include "groundx.layout.api.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "node"     (include "groundx.layout.api.node" .)
  "replicas" ($rep)
-}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.api.serviceName" .) -}}
{{- $_ := set $cfg "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.api.image" .) -}}
{{- $_ := set $cfg "isRoute"      (include "groundx.layout.api.isRoute" .) -}}
{{- $_ := set $cfg "loadBalancer" (include "groundx.layout.api.loadBalancer" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.layout.api.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.api.imagePullPolicy" .) -}}
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
