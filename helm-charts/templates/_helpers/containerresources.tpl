{{- define "groundx.renderContainerResources" -}}
{{- $ctx := .ctx -}}
{{- $indent := .indent | default 0 -}}
{{- if and
  $ctx
  (or
    (and $ctx.limits (or $ctx.limits.cpu $ctx.limits.memory $ctx.limits.gpu))
    (and $ctx.requests (or $ctx.requests.cpu $ctx.requests.memory $ctx.requests.gpu))
  )
}}
{{ printf "%*s" $indent "" }}resources:
{{- if $ctx.limits }}
{{ printf "%*s" (add $indent 2) "" }}limits:
{{- if $ctx.limits.cpu }}
{{ printf "%*s" (add $indent 4) "" }}cpu: {{ $ctx.limits.cpu }}
{{- end }}
{{- if $ctx.limits.memory }}
{{ printf "%*s" (add $indent 4) "" }}memory: {{ $ctx.limits.memory | quote }}
{{- end }}
{{- if $ctx.limits.gpu }}
{{ printf "%*s" (add $indent 4) "" }}nvidia.com/gpu: {{ $ctx.limits.gpu }}
{{- end }}
{{- end }}
{{- if $ctx.requests }}
{{ printf "%*s" (add $indent 2) "" }}requests:
{{- if $ctx.requests.cpu }}
{{ printf "%*s" (add $indent 4) "" }}cpu: {{ $ctx.requests.cpu }}
{{- end }}
{{- if $ctx.requests.memory }}
{{ printf "%*s" (add $indent 4) "" }}memory: {{ $ctx.requests.memory | quote }}
{{- end }}
{{- if $ctx.requests.gpu }}
{{ printf "%*s" (add $indent 4) "" }}nvidia.com/gpu: {{ $ctx.requests.gpu }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}