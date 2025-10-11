{{- define "groundx.extract.serviceName" -}}
{{- $in := .Values.extract | default dict -}}
{{ dig "serviceName" "extract" $in }}
{{- end }}

{{- define "groundx.extract.create" -}}
{{- $in := .Values.extract | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.extract.services" -}}
{{- $svcs := dict -}}
{{- $ic := include "groundx.extract.agent.create" . -}}
{{- if eq $ic "true" -}}
{{- $_ := set $svcs "extract.agent" "extract.agent" -}}
{{- end -}}
{{- $im := include "groundx.extract.download.create" . -}}
{{- if eq $im "true" -}}
{{- $_ := set $svcs "extract.download" "extract.download" -}}
{{- end -}}
{{- $is := include "groundx.extract.save.create" . -}}
{{- if eq $is "true" -}}
{{- $_ := set $svcs "extract.save" "extract.save" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
