{{- define "groundx.groundx.node" -}}
{{- $in := .Values.groundx | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

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
{{- $in := .Values.groundx | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/groundx:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.groundx.imagePullPolicy" -}}
{{- $in := .Values.groundx | default dict -}}
{{ dig "imagePullPolicy" "IfNotPresent" $in }}
{{- end }}

{{- define "groundx.groundx.isRoute" -}}
{{- $in := .Values.groundx | default dict -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- $os := include "groundx.isOpenshift" . -}}
{{- $ty := (dig "type" "LoadBalancer" $lb) | trim | lower -}}
{{- if or (eq $ty "route") (and (eq $ty "loadbalancer") (eq $os "true")) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.groundx.port" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{ dig "port" 80 $lb }}
{{- else -}}
80
{{- end -}}
{{- end }}

{{- define "groundx.groundx.replicas" -}}
{{- $b := .Values.groundx | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.groundx.ssl" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
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
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.groundx.type" -}}
{{- $in := .Values.groundx | default dict -}}
{{ (dig "type" "all" $in) }}
{{- end }}

{{- define "groundx.groundx.loadBalancer" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "isRoute"    (include "groundx.groundx.isRoute" .)
    "port"       (include "groundx.groundx.port" .)
    "ssl"        (include "groundx.groundx.ssl" .)
    "targetPort" (include "groundx.groundx.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "LoadBalancer" $lb)
  | toYaml -}}
{{- else -}}
{{- dict
    "isInternal" "false"
    "isRoute"    (include "groundx.groundx.isRoute" .)
    "port"       (include "groundx.groundx.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.groundx.containerPort" .)
    "timeout"    ""
    "type"       "LoadBalancer"
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.groundx.settings" -}}
{{- $in := .Values.groundx | default dict -}}

{{- $dpnd := dict
  "cache"  "cache"
  "file"   "file"
  "search" "search"
  "db"     "db"
-}}
{{- $cd := include "groundx.stream.create" . -}}
{{- $ed := include "groundx.stream.existing" . -}}
{{- if or (eq $cd "true") (eq $ed "true") -}}
{{- $_ := set $dpnd "stream" "stream" -}}
{{- end -}}

{{- $rep := (include "groundx.groundx.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "dependencies" $dpnd
  "image"        (include "groundx.groundx.image" .)
  "isRoute"      (include "groundx.groundx.isRoute" .)
  "loadBalancer" (include "groundx.groundx.loadBalancer" . | trim)
  "name"         (include "groundx.groundx.serviceName" .)
  "node"         (include "groundx.groundx.node" .)
  "port"         (include "groundx.groundx.containerPort" .)
  "pull"         (include "groundx.groundx.imagePullPolicy" .)
  "replicas"     ($rep)
-}}
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
