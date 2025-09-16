{{- define "groundx.renderProbes" -}}

{{- $ctx := .ctx -}}
{{- $indent := .indent | default 0 -}}

{{- $probes := list -}}
{{- if $ctx.livenessProbe }}
  {{- $probes = append $probes (dict "name" "livenessProbe" "spec" $ctx.livenessProbe) }}
{{- end }}
{{- if $ctx.readinessProbe }}
  {{- $probes = append $probes (dict "name" "readinessProbe" "spec" $ctx.readinessProbe) }}
{{- end }}

{{- range $probe := $probes }}
{{ printf "%*s" $indent "" }}{{ $probe.name}}:
{{- with $probe.spec.exec }}
{{ printf "%*s" (add $indent 2) "" }}exec:
{{ printf "%*s" (add $indent 4) "" }}command: {{ .command }}
{{- end }}
{{- with $probe.spec.httpGet }}
{{ printf "%*s" (add $indent 2) "" }}httpGet:
{{- if .path }}
{{ printf "%*s" (add $indent 4) "" }}path: {{ .path }}
{{- end }}
{{- if .port }}
{{ printf "%*s" (add $indent 4) "" }}port: {{ .port }}
{{- end }}
{{- end }}
{{- if $probe.spec.initialDelaySeconds }}
{{ printf "%*s" (add $indent 2) "" }}initialDelaySeconds: {{ $probe.spec.initialDelaySeconds }}
{{- end }}
{{- if $probe.spec.failureThreshold }}
{{ printf "%*s" (add $indent 2) "" }}failureThreshold: {{ $probe.spec.failureThreshold }}
{{- end }}
{{- if $probe.spec.periodSeconds }}
{{ printf "%*s" (add $indent 2) "" }}periodSeconds: {{ $probe.spec.periodSeconds }}
{{- end }}
{{- end }}

{{- end }}