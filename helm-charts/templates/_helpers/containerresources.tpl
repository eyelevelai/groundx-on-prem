{{- define "groundx.renderContainerResources" -}}
{{- $ctx := .ctx -}}
{{- $indent := .indent | default 0 -}}
{{- if and
  $ctx.resources
  (or
    (and $ctx.resources.limits (or $ctx.resources.limits.cpu $ctx.resources.limits.memory $ctx.resources.limits.gpu))
    (and $ctx.resources.requests (or $ctx.resources.requests.cpu $ctx.resources.requests.memory $ctx.resources.requests.gpu))
  )
}}
{{ printf "%*s" $indent "" }}resources:
{{- if $ctx.limits }}
{{ printf "%*s" (add $indent 2) "" }}limits:
{{- if $ctx.limits.cpu }}
{{ printf "%*s" (add $indent 4) "" }}cpu: {{ $ctx.limits.cpu | quote }}
{{- end }}
{{- if $ctx.limits.memory }}
{{ printf "%*s" (add $indent 4) "" }}memory: {{ $ctx.limits.memory | quote }}
{{- end }}
{{- if $ctx.limits.gpu }}
{{ printf "%*s" (add $indent 4) "" }}nvidia.com/gpu: {{ $ctx.limits.gpu }}
{{- end }}
{{- end }}
{{- if $ctx.resources }}
{{ printf "%*s" (add $indent 2) "" }}resources:
{{- if $ctx.resources.cpu }}
{{ printf "%*s" (add $indent 4) "" }}cpu: {{ $ctx.resources.cpu | quote }}
{{- end }}
{{- if $ctx.resources.memory }}
{{ printf "%*s" (add $indent 4) "" }}memory: {{ $ctx.resources.memory | quote }}
{{- end }}
{{- if $ctx.resources.gpu }}
{{ printf "%*s" (add $indent 4) "" }}nvidia.com/gpu: {{ $ctx.resources.gpu }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}