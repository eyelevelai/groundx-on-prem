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

{{- define "groundx.redis.yamlScalar" -}}
{{ . | quote }}
{{- end }}

{{- define "groundx.redis.userinfoEscape" -}}
{{- urlquery . | replace "+" "%20" -}}
{{- end }}

{{- define "groundx.cache.password" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{ coalesce (dig "password" "" $ex) (dig "password" "" $in) | default "" }}
{{- end }}

{{- define "groundx.cache.username" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{ coalesce (dig "username" "" $ex) (dig "username" "" $in) | default "" }}
{{- end }}

{{- define "groundx.cache.userinfo" -}}
{{- $password := include "groundx.cache.password" . -}}
{{- if ne $password "" -}}
{{- $username := include "groundx.cache.username" . -}}
{{ printf "%s:%s@" (include "groundx.redis.userinfoEscape" $username) (include "groundx.redis.userinfoEscape" $password) }}
{{- end -}}
{{- end }}

{{- define "groundx.cache.isExternal" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := (dig "existing" nil $in) | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.password" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- $ex := (dig "existing" nil $m) | default dict -}}
{{- if not (dig "enabled" false $m) -}}
{{- include "groundx.cache.password" . -}}
{{- else -}}
{{- $own := coalesce (dig "password" "" $ex) (dig "password" "" $m) -}}
{{ $own | default "" }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.username" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- $ex := (dig "existing" nil $m) | default dict -}}
{{- if not (dig "enabled" false $m) -}}
{{- include "groundx.cache.username" . -}}
{{- else -}}
{{- $own := coalesce (dig "username" "" $ex) (dig "username" "" $m) -}}
{{ $own | default "" }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.userinfo" -}}
{{- $password := include "groundx.metrics.cache.password" . -}}
{{- if ne $password "" -}}
{{- $username := include "groundx.metrics.cache.username" . -}}
{{ printf "%s:%s@" (include "groundx.redis.userinfoEscape" $username) (include "groundx.redis.userinfoEscape" $password) }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.isExternal" -}}
{{- $b := .Values.cache | default dict -}}
{{- $m := (dig "metrics" nil $b) | default dict -}}
{{- $ex := (dig "existing" nil $m) | default dict -}}
{{- if (dig "enabled" false $m) -}}
{{- if not (empty (dig "addr" "" $ex)) -}}true{{- else -}}false{{- end -}}
{{- else -}}
{{ include "groundx.cache.isExternal" . }}
{{- end -}}
{{- end }}

{{- define "groundx.cache.validateCredentials" -}}
{{- $cachePassword := include "groundx.cache.password" . -}}
{{- $cacheUsername := include "groundx.cache.username" . -}}
{{- $cacheExternal := include "groundx.cache.isExternal" . | trim -}}
{{- if or (ne $cachePassword "") (ne $cacheUsername "") -}}
  {{- if ne $cacheExternal "true" -}}
    {{- fail "cache.password/cache.username require an external Redis (cache.existing.addr); the chart's own bundled Redis has no AUTH support" -}}
  {{- end -}}
{{- end -}}
{{- if and (eq $cacheExternal "true") (ne $cacheUsername "") (eq $cachePassword "") -}}
  {{- fail "cache.username requires cache.password to also be set; a username with no password (nopass ACL) is not supported" -}}
{{- end -}}
{{- $metricsPassword := include "groundx.metrics.cache.password" . -}}
{{- $metricsUsername := include "groundx.metrics.cache.username" . -}}
{{- $metricsExternal := include "groundx.metrics.cache.isExternal" . | trim -}}
{{- if or (ne $metricsPassword "") (ne $metricsUsername "") -}}
  {{- if ne $metricsExternal "true" -}}
    {{- fail "cache.metrics.password/cache.metrics.username require an external Redis (cache.metrics.existing.addr) or an external main cache; the chart's own bundled Redis has no AUTH support" -}}
  {{- end -}}
{{- end -}}
{{- if and (eq $metricsExternal "true") (ne $metricsUsername "") (eq $metricsPassword "") -}}
  {{- fail "cache.metrics.username requires cache.metrics.password to also be set; a username with no password (nopass ACL) is not supported" -}}
{{- end -}}
{{- $rankerPassword := include "groundx.ranker.cache.password" . -}}
{{- $rankerUsername := include "groundx.ranker.cache.username" . -}}
{{- $rankerExternal := include "groundx.ranker.cache.isExternal" . | trim -}}
{{- if or (ne $rankerPassword "") (ne $rankerUsername "") -}}
  {{- if ne $rankerExternal "true" -}}
    {{- fail "ranker.cache.password/ranker.cache.username require an external Redis (ranker.cache.addr) or an external main cache; the chart's own bundled Redis has no AUTH support" -}}
  {{- end -}}
{{- end -}}
{{- if and (eq $rankerExternal "true") (ne $rankerUsername "") (eq $rankerPassword "") -}}
  {{- fail "ranker.cache.username requires ranker.cache.password to also be set; a username with no password (nopass ACL) is not supported" -}}
{{- end -}}
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
