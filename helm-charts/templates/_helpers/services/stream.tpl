{{- define "groundx.stream.serviceName" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "serviceName" "stream" $in }}
{{- end }}

{{- define "groundx.stream.existing" -}}
{{- $ex := .Values.stream.existing | default dict -}}
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

{{- define "groundx.stream.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.stream.serviceName" . -}}
{{- printf "%s-cluster-kafka-bootstrap.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.stream.domain" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- $in := .Values.stream | default dict -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "domain" "" $ex }}
{{- else -}}
{{ include "groundx.stream.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.stream.port" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- $in := .Values.stream | default dict -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" "" $ex }}
{{- else -}}
{{ dig "port" 9092 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.stream.metaVersion" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "metaVersion" "4.0-IV3" $in }}
{{- end }}

{{- define "groundx.stream.retention" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "retention" "1073741824" $in }}
{{- end }}

{{- define "groundx.stream.segment" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "segment" "1073741824" $in }}
{{- end }}

{{- define "groundx.stream.version" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "version" "4.0.0" $in }}
{{- end }}

{{- define "groundx.stream.topics" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" (list) $in -}}
{{- if not (empty $topics) -}}
{{- toYaml $topics -}}
{{- else -}}
{{- $p := 3 -}}
{{- toYaml (dict
  .Values.preProcess.internal.queue    .Values.preProcess.internal.replicas.desired
  .Values.process.internal.queue       .Values.process.internal.replicas.desired
  .Values.summaryClient.internal.queue .Values.summaryClient.internal.replicas.desired
  .Values.queue.internal.queue         .Values.queue.internal.replicas.desired
  .Values.upload.internal.queue        .Values.upload.internal.replicas.desired
) -}}
{{- end -}}
{{- end }}
