{{- define "groundx.cache.node" -}}
{{- $in := .Values.cache | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.cache.create" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.create" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- if (dig "enabled" false $in) -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
false
{{- else -}}
{{ include "groundx.cache.create" . }}
{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.cache.serviceName" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "serviceName" "cache" $in }}
{{- end }}

{{- define "groundx.metrics.cache.node" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.metrics.cache.serviceName" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{ dig "serviceName" "metrics" $in }}
{{- end }}

{{- define "groundx.cache.containerPort" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "containerPort" 6379 $in }}
{{- end }}

{{- define "groundx.metrics.cache.containerPort" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{ dig "containerPort" 6379 $in }}
{{- end }}

{{- define "groundx.cache.image" -}}
{{- $in := .Values.cache | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $fallback := printf "%s/eyelevel/redis:latest" $repoPrefix -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.metrics.cache.image" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $fallback := printf "%s/eyelevel/redis:latest" $repoPrefix -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.cache.imagePullPolicy" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "imagePullPolicy" "Always" $in }}
{{- end }}

{{- define "groundx.metrics.cache.imagePullPolicy" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{ dig "imagePullPolicy" "Always" $in }}
{{- end }}

{{- define "groundx.cache.isRoute" -}}
{{- $lb := (include "groundx.cache.loadBalancer" . | fromYaml) -}}
{{- $os := include "groundx.isOpenshift" . -}}
{{- $ty := (dig "type" "ClusterIP" $lb) | trim | lower -}}
{{- if or (eq $ty "route") (and (eq $ty "loadbalancer") (eq $os "true")) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.isRoute" -}}
{{- $lb := (include "groundx.metrics.cache.loadBalancer" . | fromYaml) -}}
{{- $os := include "groundx.isOpenshift" . -}}
{{- $ty := (dig "type" "ClusterIP" $lb) | trim | lower -}}
{{- if or (eq $ty "route") (and (eq $ty "loadbalancer") (eq $os "true")) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.cache.mountPath" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "mountPath" "/mnt/redis" $in }}
{{- end }}

{{- define "groundx.metrics.cache.mountPath" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{ dig "mountPath" "/mnt/redis" $in }}
{{- end }}

{{- define "groundx.cache.replicas" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.cache.addr" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- $svc := include "groundx.cache.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "addr" "" $ex) (printf "%s.%s.svc.cluster.local" $svc $ns) -}}
{{- end }}

{{- define "groundx.cache.isCluster" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "isCluster" "true" $ex }}
{{- else -}}
{{- $rep := (include "groundx.cache.replicas" . | fromYaml) -}}
{{- $desired := int (dig "desired" 1 $rep) -}}
{{- if gt $desired 1 -}}true{{- else -}}false{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.cache.notCluster" -}}
{{- $ic := include "groundx.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.cache.port" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "port" 6379 $ex }}
{{- else -}}
{{ dig "port" 6379 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.addr" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- $svc := include "groundx.cache.serviceName" . -}}
{{- $msvc := include "groundx.metrics.cache.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- if (dig "enabled" false $m) -}}
  {{- coalesce (dig "addr" "" $ex) (printf "%s-%s.%s.svc.cluster.local" $svc $msvc $ns) -}}
{{- else -}}
  {{- include "groundx.cache.addr" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.isCluster" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- if (dig "enabled" false $m) -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "isCluster" "true" $ex }}
{{- else -}}
{{- $rep := (include "groundx.metrics.cache.replicas" . | fromYaml) -}}
{{- $desired := int (dig "desired" 1 $rep) -}}
{{- if gt $desired 1 -}}true{{- else -}}false{{- end -}}
{{- end -}}
{{- else -}}
{{ include "groundx.cache.isCluster" . }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.notCluster" -}}
{{- $ic := include "groundx.metrics.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.port" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- if (dig "enabled" false $m) -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "port" 6379 $ex }}
{{- else -}}
{{ dig "port" 6379 $m }}
{{- end -}}
{{- else -}}
{{ include "groundx.cache.port" . }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.replicas" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := dig "metrics" dict $b  -}}
{{- $in := dig "replicas" dict $m -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.cache.loadBalancer" -}}
{{- $in := .Values.cache | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.cache.port" .)
    "ssl"        (dig "ssl" "false" $lb)
    "targetPort" (include "groundx.cache.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- else -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.cache.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.cache.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.loadBalancer" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- if hasKey $in "loadBalancer" -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (include "groundx.metrics.cache.port" .)
    "ssl"        (dig "ssl" "false" $lb)
    "targetPort" (include "groundx.metrics.cache.containerPort" .)
    "timeout"    (dig "timeout" "" $lb)
    "type"       (dig "type" "ClusterIP" $lb)
  | toYaml -}}
{{- else -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.metrics.cache.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.metrics.cache.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end -}}
{{- end }}
