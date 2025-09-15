{{- define "groundx.search.create" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $hasSearch := not (.Values.ingestOnly | default false) -}}
{{- and $hasSearch (or (not (hasKey $ex "domain")) (not (hasKey $ex "url")) (not (hasKey $ex "port"))) -}}
{{- end }}

{{- define "groundx.search.baseDomain" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $in := .Values.search.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "domain" "" $ex) (printf "%s-cluster-master.%s.svc.cluster.local" (dig "serviceName" "search" $in) $ns) -}}
{{- end }}

{{- define "groundx.search.port" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $in := .Values.search.internal | default dict -}}
{{- coalesce (dig "port" "" $ex) (dig "port" 9200 $in) -}}
{{- end }}

{{- define "groundx.search.baseURL" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $in := .Values.search.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- $svc := dig "serviceName" "search" $in -}}
{{- $port := include "groundx.search.port" . -}}
{{- coalesce (dig "url" "" $ex) (printf "https://%s-cluster-master.%s.svc.cluster.local:%v" $svc $ns $port) -}}
{{- end }}
