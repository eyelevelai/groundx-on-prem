{{- define "groundx.renderInitContainers" -}}

{{- $ctx := .ctx -}}
{{- $indent := .indent | default 0 -}}

{{- if $ctx }}
{{ printf "%*s" $indent "" }}initContainers:
{{- range $j, $ic := $ctx }}
{{ printf "%*s" (add $indent 2) "" }}- name: {{ $ic.name }}
{{ printf "%*s" (add $indent 4) "" }}image: {{ $ic.image }}
{{ printf "%*s" (add $indent 4) "" }}imagePullPolicy: {{ $ic.imagePullPolicy | quote }}
{{- if kindIs "slice" $ic.command }}
{{ printf "%*s" (add $indent 4) "" }}command:
{{- range $cmd := $ic.command }}
{{ printf "%*s" (add $indent 6) "" }}- {{ $cmd | quote }}
{{- end }}
{{- else if $ic.command }}
{{ printf "%*s" (add $indent 4) "" }}command: {{ $ic.command | quote }}
{{- end }}
{{- if $ic.args }}
{{ printf "%*s" (add $indent 4) "" }}args:
{{- range $arg := $ic.args }}
{{ printf "%*s" (add $indent 6) "" }}- {{ $arg | quote }}
{{- end }}
{{- end }}
{{ include "groundx.renderSecurityContext" (dict "ctx" $ic.securityContext "indent" (add $indent 4)) }}
{{ include "groundx.renderResources" (dict "ctx" $ic.resources "indent" (add $indent 4)) }}
{{ include "groundx.renderVolumeMounts" (dict "ctx" $ic.volumeMounts "indent" (add $indent 4)) }}
{{- end }}
{{- end }}

{{- end }}
