{{- define "groundx.stream.create" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- or (not (hasKey $ex "domain")) (not (hasKey $ex "port")) -}}
{{- end }}

{{- define "groundx.stream.baseDomain" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- $in := .Values.stream.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "domain" "" $ex) (printf "%s-cluster-kafka-bootstrap.%s.svc.cluster.local" (dig "serviceName" "kafka" $in) $ns) -}}
{{- end }}

{{- define "groundx.stream.port" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- $in := .Values.stream.internal | default dict -}}
{{- coalesce (dig "port" "" $ex) (dig "port" 9092 $in) -}}
{{- end }}
