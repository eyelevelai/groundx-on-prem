{{- define "groundx.renderTopologySpread" -}}
{{- $ctx := .ctx | default list -}}
{{- $indent := .indent | default 0 -}}
{{- if gt (len $ctx) 0 }}
{{ printf "%*s" $indent "" }}topologySpreadConstraints:{{ $ctx | toYaml | nindent (int (add $indent 2)) }}
{{- end }}
{{- end }}
