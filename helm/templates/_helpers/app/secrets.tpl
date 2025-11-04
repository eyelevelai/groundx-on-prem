{{- define "groundx.app.secrets" -}}

{{- $svcs := dict -}}

{{- $il := include "groundx.extract.agent.create" . -}}
{{- $es := include "groundx.extract.agent.existingSecret" . -}}
{{- if and (eq $il "true") (eq $es "false") -}}
{{- $_ := set $svcs "extract.agent" "extract.agent" -}}
{{- end -}}

{{- $is := include "groundx.extract.save.create" . -}}
{{- $eg := include "groundx.extract.save.existingSecret" . -}}
{{- $gc := include "groundx.extract.save.gcpCredentials" . -}}
{{- if and (eq $is "true") (eq $eg "false") (ne $gc "") -}}
{{- $_ := set $svcs "extract.save" "extract.save" -}}
{{- end -}}

{{- $svcs | toYaml -}}

{{- end }}
