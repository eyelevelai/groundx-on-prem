{{- define "groundx.renderNodeSelector" -}}
{{- $ctx := .ctx | default dict -}}
{{- $node := .node -}}
{{- $indent := .indent | default 0 -}}
{{- $root := .root -}}
{{- if gt (len $ctx) 0 }}
{{ printf "%*s" $indent "" }}nodeSelector:{{ $ctx | toYaml | nindent (int (add $indent 2)) }}
{{- else if ne $node "" }}
{{ printf "%*s" $indent "" }}nodeSelector:
{{ printf "%*s" (add $indent 2) "" }}node: {{ $node | quote }}
{{- end }}
{{- end }}
