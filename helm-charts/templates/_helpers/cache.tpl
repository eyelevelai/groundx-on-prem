{{- define "groundx.cache.image" -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $img := dig "image" nil $in -}}
{{- if $img -}}
  {{- $img -}}
{{- else -}}
  {{- printf "%s/%s:%s" $repoPrefix "eyelevel/redis" "latest" -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.image" -}}
{{- $in := .Values.cache.metrics.internal | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $img := dig "image" nil $in -}}
{{- if $img -}}
  {{- $img -}}
{{- else -}}
  {{- printf "%s/%s:%s" $repoPrefix "eyelevel/redis" "latest" -}}
{{- end -}}
{{- end }}

{{- define "groundx.cache.imagePullPolicy" -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- $policy := dig "imagePullPolicy" "" $in -}}
{{- if $policy -}}
{{ $policy }}
{{- else -}}
Always
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.imagePullPolicy" -}}
{{- $in := .Values.cache.metrics.internal | default dict -}}
{{- $policy := dig "imagePullPolicy" "" $in -}}
{{- if $policy -}}
{{ $policy }}
{{- else -}}
Always
{{- end -}}
{{- end }}

{{- define "groundx.cache.mountPath" -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- $mp := dig "mountPath" "" $in -}}
{{- if $mp -}}
{{ $mp }}
{{- else -}}
/mnt/redis
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.mountPath" -}}
{{- $in := .Values.cache.metrics.internal | default dict -}}
{{- $mp := dig "mountPath" "" $in -}}
{{- if $mp -}}
{{ $mp }}
{{- else -}}
/mnt/redis
{{- end -}}
{{- end }}

{{- define "groundx.cache.create" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- or (empty (dig "addr" "" $ex)) (empty (dig "isCluster" "" $ex)) (empty (dig "port" "" $ex)) -}}
{{- end }}

{{- define "groundx.cache.addr" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "addr" "" $ex) (printf "%s.%s.svc.cluster.local" (dig "serviceName" "redis" $in) $ns) -}}
{{- end }}

{{- define "groundx.cache.isCluster" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- $ic := coalesce (dig "isCluster" "" $ex) (dig "isCluster" "" $in) -}}
{{- if eq (printf "%v" $ic) "true" -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.cache.notCluster" -}}
{{- $ic := include "groundx.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.cache.port" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- coalesce (dig "port" "" $ex) (dig "port" 6379 $in) -}}
{{- end }}

{{- define "groundx.metrics.cache.create" -}}
{{- and (include "groundx.cache.create" . | fromYaml) (dig "metrics" "enabled" false .Values.cache) -}}
{{- end }}

{{- define "groundx.metrics.cache.addr" -}}
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- $in := dig "internal" dict $m -}}
{{- $ns := include "groundx.ns" . -}}
{{- if (dig "enabled" false $m) -}}
  {{- coalesce (dig "addr" "" $ex) (printf "%s-%s.%s.svc.cluster.local" (dig "serviceName" "redis" (.Values.cache.internal | default dict)) (dig "serviceName" "metrics" $in) $ns) -}}
{{- else -}}
  {{- include "groundx.cache.addr" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.isCluster" -}}
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- $in := dig "internal" dict $m -}}
{{- if (dig "enabled" false $m) -}}
  {{- $ic := coalesce (dig "isCluster" "" $ex) (dig "isCluster" "" $in) -}}
  {{- if eq (printf "%v" $ic) "true" -}}true{{- else -}}false{{- end -}}
{{- else -}}
  {{- include "groundx.cache.isCluster" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.notCluster" -}}
{{- $ic := include "groundx.metrics.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.port" -}}
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- $in := dig "internal" dict $m -}}
{{- if (dig "enabled" false $m) -}}
  {{- coalesce (dig "port" "" $ex) (dig "port" 6379 $in) -}}
{{- else -}}
  {{- include "groundx.cache.port" . -}}
{{- end -}}
{{- end }}
