{{- define "groundx.renderTolerations" -}}
{{- $ctx := .ctx | default dict -}}
{{- $node := .node -}}
{{- $indent := .indent | default 0 -}}
{{- $root := .root -}}
{{- if gt (len $ctx) 0 }}
{{ printf "%*s" $indent "" }}tolerations:{{ $ctx | toYaml | nindent (int (add $indent 2)) }}
{{- else if ne $node "" }}
{{ printf "%*s" $indent "" }}tolerations:
{{ printf "%*s" (add $indent 2) "" }}- key: "node"
{{ printf "%*s" (add $indent 4) "" }}value: {{ $node | quote }}
{{ printf "%*s" (add $indent 4) "" }}effect: "NoSchedule"
{{ printf "%*s" (add $indent 2) "" }}- key: "eyelevel_node"
{{ printf "%*s" (add $indent 4) "" }}value: {{ $node | quote }}
{{ printf "%*s" (add $indent 4) "" }}effect: "NoSchedule"
{{- end }}
{{- end }}
