{{- define "groundx.renderContainerResources" -}}
{{- $ctx := .ctx | default dict -}}
{{- $indent := .indent | default 0 -}}
{{- if gt (len $ctx) 0 }}
{{ printf "%*s" $indent "" }}resources:{{ $ctx | toYaml | nindent (int (add $indent 2)) }}
{{- end }}
{{- end }}