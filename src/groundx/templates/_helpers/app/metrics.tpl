{{- define "groundx.metrics.node" -}}
{{- $in := .Values.metrics | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.metrics.serviceName" -}}
{{- $in := .Values.metrics | default dict -}}
{{ dig "serviceName" "metrics" $in }}
{{- end }}

{{- define "groundx.metrics.create" -}}
{{- $in := .Values.metrics | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.metrics.containerPort" -}}
{{- $in := .Values.metrics | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.metrics.image" -}}
{{- $in := .Values.metrics | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/metrics:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.metrics.imagePullPolicy" -}}
{{- $in := .Values.metrics | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.metrics.port" -}}
80
{{- end }}

{{- define "groundx.metrics.replicas" -}}
{{- $c := .Values.metrics | default dict -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.metrics.serviceAccountName" -}}
{{- $in := .Values.metrics | default dict -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.metrics.serviceType" -}}
{{- $in := .Values.metrics | default dict -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.metrics.interface" -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.metrics.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.metrics.containerPort" .)
    "timeout"    ""
    "type"       (include "groundx.metrics.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.metrics.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.metrics.serviceName" . -}}
{{- $port := include "groundx.metrics.containerPort" . -}}
{{- if eq $port "80" -}}
{{ printf "http://%s.%s.svc.cluster.local" $name $ns }}
{{- else -}}
{{ printf "http://%s.%s.svc.cluster.local:%v" $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.settings" -}}
{{- $in := .Values.metrics | default dict -}}

{{- $dpnd := dict
  "cache"  "cache"
  "db"     "db"
-}}

{{- $rep := (include "groundx.metrics.replicas" . | fromYaml) -}}
{{- $san := include "groundx.metrics.serviceAccountName" . -}}

{{- $cfg := dict
  "dependencies" $dpnd
  "image"        (include "groundx.metrics.image" .)
  "interface"    (include "groundx.metrics.interface" . | trim)
  "name"         (include "groundx.metrics.serviceName" .)
  "node"         (include "groundx.metrics.node" .)
  "port"         (include "groundx.metrics.containerPort" .)
  "pull"         (include "groundx.metrics.imagePullPolicy" .)
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
