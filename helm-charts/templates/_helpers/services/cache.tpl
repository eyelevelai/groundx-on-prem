{{- define "groundx.cache.serviceName" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "serviceName" "cache" $in }}
{{- end }}

{{- define "groundx.metrics.cache.serviceName" -}}
{{- $in := .Values.cache.metrics | default dict -}}
{{ dig "serviceName" "metrics" $in }}
{{- end }}

{{- define "groundx.cache.image" -}}
{{- $in := .Values.cache | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $fallback := printf "%s/%s:%s" $repoPrefix "eyelevel/redis" "latest" -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.metrics.cache.image" -}}
{{- $in := .Values.cache.metrics | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $fallback := printf "%s/%s:%s" $repoPrefix "eyelevel/redis" "latest" -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.cache.imagePullPolicy" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "imagePullPolicy" "Always" $in }}
{{- end }}

{{- define "groundx.metrics.cache.imagePullPolicy" -}}
{{- $in := .Values.cache.metrics | default dict -}}
{{ dig "imagePullPolicy" "Always" $in }}
{{- end }}

{{- define "groundx.cache.mountPath" -}}
{{- $in := .Values.cache | default dict -}}
{{ dig "mountPath" "/mnt/redis" $in }}
{{- end }}

{{- define "groundx.metrics.cache.mountPath" -}}
{{- $in := .Values.cache.metrics | default dict -}}
{{ dig "mountPath" "/mnt/redis" $in }}
{{- end }}

{{- define "groundx.cache.create" -}}
{{- $in := .Values.cache | default dict -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.cache.addr" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $svc := include "groundx.cache.serviceName" . -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "addr" "" $ex) (printf "%s.%s.svc.cluster.local" $svc $ns) -}}
{{- end }}

{{- define "groundx.cache.isCluster" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "isCluster" "true" $ex }}
{{- else -}}
{{ dig "isCluster" "false" $in }}
{{- end -}}
{{- end }}

{{- define "groundx.cache.notCluster" -}}
{{- $ic := include "groundx.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.cache.port" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "port" "" $ex }}
{{- else -}}
{{ dig "port" 6379 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.create" -}}
{{- if (dig "enabled" false .Values.cache.metrics) -}}
{{- $ex := .Values.cache.metrics.existing | default dict -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
false
{{- else -}}
{{ include "groundx.cache.create" . }}
{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.addr" -}}
{{- $m  := .Values.cache.metrics | default dict -}}
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
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- if (dig "enabled" false $m) -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "isCluster" "true" $ex }}
{{- else -}}
{{ dig "isCluster" "false" $m }}
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
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- if (dig "enabled" false $m) -}}
{{- if not (empty (dig "addr" "" $ex)) -}}
{{ dig "port" "" $ex }}
{{- else -}}
{{ dig "port" 6379 $m }}
{{- end -}}
{{- else -}}
{{ include "groundx.cache.port" . }}
{{- end -}}
{{- end }}
