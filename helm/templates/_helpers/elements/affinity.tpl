{{- define "groundx.renderAffinity" -}}
{{- $ctx := .ctx | default dict -}}
{{- $node := .node -}}
{{- $indent := .indent | default 0 -}}
{{- $root := .root -}}
{{- if gt (len $ctx) 0 }}
{{ printf "%*s" $indent "" }}affinity:{{ $ctx | toYaml | nindent (int (add $indent 2)) }}
{{- else if ne $node "" }}
{{ printf "%*s" $indent "" }}affinity:
{{ printf "%*s" (add $indent 2) "" }}nodeAffinity:
{{ printf "%*s" (add $indent 4) "" }}requiredDuringSchedulingIgnoredDuringExecution:
{{ printf "%*s" (add $indent 6) "" }}nodeSelectorTerms:
{{ printf "%*s" (add $indent 8) "" }}- matchExpressions:
{{ printf "%*s" (add $indent 10) "" }}- key: node
{{ printf "%*s" (add $indent 12) "" }}operator: In
{{ printf "%*s" (add $indent 12) "" }}values: [{{ $node | quote }}]
{{ printf "%*s" (add $indent 8) "" }}- matchExpressions:
{{ printf "%*s" (add $indent 10) "" }}- key: eyelevel_node
{{ printf "%*s" (add $indent 12) "" }}operator: In
{{ printf "%*s" (add $indent 12) "" }}values: [{{ $node | quote }}]
{{- end }}
{{- end }}
