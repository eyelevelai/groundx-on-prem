{{- define "groundx.stream.serviceName" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "serviceName" "stream" $in }}
{{- end }}

{{- define "groundx.stream.existing" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{ not (empty (dig "domain" "" $ex)) }}
{{- end }}

{{- define "groundx.stream.create" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.stream.domain" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "domain" "" $ex }}
{{- else -}}
{{ include "groundx.stream.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.stream.key" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "key" "" $in }}
{{- end }}

{{- define "groundx.stream.port" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" 9092 $ex }}
{{- else -}}
{{ dig "port" 9092 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.stream.region" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "region" "" $in }}
{{- end }}

{{- define "groundx.stream.replicas" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "replicas" 1 $in }}
{{- end }}

{{- define "groundx.stream.retention" -}}
{{- $in := .Values.topic | default dict -}}
{{ dig "retention" "1073741824" $in }}
{{- end }}

{{- define "groundx.stream.secret" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "secret" "" $in }}
{{- end }}

{{- define "groundx.stream.segment" -}}
{{- $in := .Values.topic | default dict -}}
{{ dig "segment" "1073741824" $in }}
{{- end }}

{{- define "groundx.stream.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.stream.serviceName" . -}}
{{- printf "%s-cluster-kafka-bootstrap.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.stream.token" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "token" "" $in }}
{{- end }}
