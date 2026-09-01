{{- define "groundx.ranker.serviceName" -}}
{{- $in := .Values.ranker | default dict -}}
{{ dig "serviceName" "ranker" $in }}
{{- end }}

{{- define "groundx.ranker.cache.existing" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- if not (empty (dig "addr" "" $in)) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.addr" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
{{ dig "addr" "" $in }}
{{- else -}}
{{ include "groundx.cache.addr" . }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.port" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
{{ dig "port" 6379 $in }}
{{- else -}}
{{ include "groundx.cache.port" . }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.ssl" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
{{ dig "ssl" false $in }}
{{- else -}}
{{ include "groundx.cache.ssl" . }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.isCluster" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
{{ dig "isCluster" "true" $in }}
{{- else -}}
{{ include "groundx.cache.isCluster" . }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.notCluster" -}}
{{- $ic := include "groundx.ranker.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.scheme" -}}
{{- $ssl := include "groundx.ranker.cache.ssl" . | trim | lower -}}
{{- if eq $ssl "true" -}}rediss{{- else -}}redis{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.type" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
{{ dig "type" "redis" $in }}
{{- else -}}
{{ include "groundx.cache.type" . }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.create" -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
false
{{- else -}}
{{ include "groundx.cache.create" . }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.password" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- $own := dig "password" "" $in -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
{{ $own | default "" }}
{{- else -}}
{{- $main := include "groundx.cache.password" . -}}
{{ coalesce $own $main | default "" }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.username" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "cache" dict $b -}}
{{- $own := dig "username" "" $in -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}
{{ $own | default "" }}
{{- else -}}
{{- $main := include "groundx.cache.username" . -}}
{{ coalesce $own $main | default "" }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.userinfo" -}}
{{- $password := include "groundx.ranker.cache.password" . -}}
{{- if ne $password "" -}}
{{- $username := include "groundx.ranker.cache.username" . -}}
{{ printf "%s:%s@" (include "groundx.redis.userinfoEscape" $username) (include "groundx.redis.userinfoEscape" $password) }}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.isExternal" -}}
{{- if eq (include "groundx.ranker.cache.existing" .) "true" -}}true{{- else -}}{{ include "groundx.cache.isExternal" . }}{{- end -}}
{{- end }}

{{- define "groundx.ranker.cache.settings" -}}
{{- dict
    "addr"   (include "groundx.ranker.cache.addr" .)
    "port"   (include "groundx.ranker.cache.port" .)
    "scheme" (include "groundx.ranker.cache.scheme" .)
    "type"   (include "groundx.ranker.cache.type" .)
  | toYaml -}}
{{- end }}
