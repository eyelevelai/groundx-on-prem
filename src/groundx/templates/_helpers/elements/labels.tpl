{{- define "groundx.renderDefaultLabels" -}}
{{- $name := .name | default "" -}}
{{- $indent := .indent | default 0 -}}
{{- $root := .root -}}
{{- if ne $name "" -}}
{{ printf "%*s" $indent "" }}app: {{ $name | quote }}
{{- end }}
{{ printf "%*s" $indent "" }}appVersion: {{ $root.Chart.AppVersion | quote }}
{{ printf "%*s" $indent "" }}chart: {{ $root.Chart.Name }}-{{ $root.Chart.Version | replace "+" "_" }}
{{ printf "%*s" $indent "" }}heritage: {{ $root.Release.Service | quote }}
{{ printf "%*s" $indent "" }}version: {{ $root.Chart.Version | quote }}
{{- end }}