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

{{- define "groundx.cache.type" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{ dig "type" "redis" $ex }}
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
{{- $fallback := printf "%s/eyelevel/redis:1.0.0" $repoPrefix -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.metrics.cache.image" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $fallback := printf "%s/eyelevel/redis:1.0.0" $repoPrefix -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.cache.imagePullPolicy" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.metrics.cache.imagePullPolicy" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.cache.mountPath" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "mountPath" "/mnt/redis" $in }}
{{- end }}

{{- define "groundx.cache.persistence.enabled" -}}
{{- $in := .Values.cache | default dict -}}
{{- $pvc := dig "persistence" dict $in -}}
{{- if (dig "enabled" false $pvc) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.cache.persistence.capacity" -}}
{{- $in := .Values.cache | default dict -}}
{{- $pvc := dig "persistence" dict $in -}}
{{ dig "capacity" "10Gi" $pvc }}
{{- end }}

{{- define "groundx.metrics.cache.mountPath" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{ dig "mountPath" "/mnt/redis" $in }}
{{- end }}

{{- define "groundx.metrics.cache.persistence.enabled" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- $pvc := dig "persistence" dict $in -}}
{{- if (dig "enabled" false $pvc) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.persistence.capacity" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- $pvc := dig "persistence" dict $in -}}
{{ dig "capacity" "10Gi" $pvc }}
{{- end }}

{{- define "groundx.cache.replicas" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.cache.serviceAccountName" -}}
{{- $b := .Values.cache | default dict -}}
{{ dig "serviceAccountName" (include "groundx.serviceAccountName" .) $b }}
{{- end }}

{{- define "groundx.metrics.cache.serviceAccountName" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{ dig "serviceAccountName" (include "groundx.cache.serviceAccountName" .) $in }}
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

{{- define "groundx.cache.scheme" -}}
{{- $ic := include "groundx.cache.ssl" . -}}
{{- if eq $ic "true" -}}
rediss
{{- else -}}
redis
{{- end -}}
{{- end }}

{{- define "groundx.cache.password" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "password" "" $in }}
{{- end }}

{{- define "groundx.cache.username" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "username" "" $in }}
{{- end }}

{{- define "groundx.cache.userinfo" -}}
{{- $p := include "groundx.cache.password" . -}}
{{- $u := include "groundx.cache.username" . -}}
{{- if eq $p "" -}}
{{- else if eq $u "" -}}
{{- printf ":%s@" (urlquery $p | replace "+" "%20") -}}
{{- else -}}
{{- printf "%s:%s@" (urlquery $u | replace "+" "%20") (urlquery $p | replace "+" "%20") -}}
{{- end -}}
{{- end }}

{{- define "groundx.cache.confEnabled" -}}
{{- $cc := include "groundx.cache.create" . | trim -}}
{{- $p := include "groundx.cache.password" . | trim -}}
{{- if and (ne $cc "false") (ne $p "") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.cache.confSecretName" -}}
{{- printf "%s-conf" (include "groundx.cache.serviceName" .) -}}
{{- end }}

{{- define "groundx.cache.confVolumeName" -}}
{{- printf "%s-conf" (include "groundx.cache.serviceName" .) -}}
{{- end }}

{{- define "groundx.cache.confMountPath" -}}
/etc/redis
{{- end }}

{{- define "groundx.redisConfEscape" -}}
{{- . | replace "\\" "\\\\" | replace "\"" "\\\"" -}}
{{- end }}

{{- define "groundx.cache.confContent" -}}
{{- $p := include "groundx.cache.password" . -}}
{{- $u := include "groundx.cache.username" . -}}
{{- $lines := list "include /etc/redis.conf" -}}
{{- if eq $u "" -}}
{{- $lines = append $lines (printf "requirepass \"%s\"" (include "groundx.redisConfEscape" $p)) -}}
{{- else -}}
{{- $lines = append $lines "user default off" -}}
{{- $lines = append $lines (printf "user %s on \">%s\" ~* &* +@all" $u (include "groundx.redisConfEscape" $p)) -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end }}

{{- define "groundx.cache.ssl" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "ssl" "false" $ex }}
{{- else -}}
false
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

{{- define "groundx.metrics.cache.scheme" -}}
{{- $ic := include "groundx.metrics.cache.ssl" . -}}
{{- if eq $ic "true" -}}
rediss
{{- else -}}
redis
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.ssl" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "ssl" "false" $ex }}
{{- else -}}
false
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

{{- define "groundx.metrics.cache.password" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- if (dig "enabled" false $m) -}}
{{ dig "password" "" $m }}
{{- else -}}
{{ include "groundx.cache.password" . }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.username" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- if (dig "enabled" false $m) -}}
{{ dig "username" "" $m }}
{{- else -}}
{{ include "groundx.cache.username" . }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.userinfo" -}}
{{- $p := include "groundx.metrics.cache.password" . -}}
{{- $u := include "groundx.metrics.cache.username" . -}}
{{- if eq $p "" -}}
{{- else if eq $u "" -}}
{{- printf ":%s@" (urlquery $p | replace "+" "%20") -}}
{{- else -}}
{{- printf "%s:%s@" (urlquery $u | replace "+" "%20") (urlquery $p | replace "+" "%20") -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.confEnabled" -}}
{{- $cc := include "groundx.metrics.cache.create" . | trim -}}
{{- $p := include "groundx.metrics.cache.password" . | trim -}}
{{- if and (ne $cc "false") (ne $p "") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.confSecretName" -}}
{{- printf "%s-%s-conf" (include "groundx.cache.serviceName" .) (include "groundx.metrics.cache.serviceName" .) -}}
{{- end }}

{{- define "groundx.metrics.cache.confVolumeName" -}}
{{- printf "%s-%s-conf" (include "groundx.cache.serviceName" .) (include "groundx.metrics.cache.serviceName" .) -}}
{{- end }}

{{- define "groundx.metrics.cache.confMountPath" -}}
/etc/redis
{{- end }}

{{- define "groundx.metrics.cache.confContent" -}}
{{- $p := include "groundx.metrics.cache.password" . -}}
{{- $u := include "groundx.metrics.cache.username" . -}}
{{- $lines := list "include /etc/redis.conf" -}}
{{- if eq $u "" -}}
{{- $lines = append $lines (printf "requirepass \"%s\"" (include "groundx.redisConfEscape" $p)) -}}
{{- else -}}
{{- $lines = append $lines "user default off" -}}
{{- $lines = append $lines (printf "user %s on \">%s\" ~* &* +@all" $u (include "groundx.redisConfEscape" $p)) -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end }}

{{- define "groundx.cache.interface" -}}
{{- $in := .Values.cache | default dict -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.cache.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.cache.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end }}

{{- define "groundx.metrics.cache.interface" -}}
{{- $b := .Values.cache | default dict -}}
{{- $in := (dig "metrics" nil $b) | default dict -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.metrics.cache.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.metrics.cache.containerPort" .)
    "timeout"    ""
    "type"       "ClusterIP"
  | toYaml -}}
{{- end }}
