{{- define "groundx.secrets" -}}
{{- $svcs := dict -}}
{{- $il := include "groundx.extract.agent.create" . -}}
{{- $es := include "groundx.extract.agent.existingSecret" . -}}
{{- if and (eq $il "true") (eq $es "false") -}}
{{- $_ := set $svcs "extract.agent" "extract.agent" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
