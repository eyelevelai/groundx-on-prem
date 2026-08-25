{{- define "groundx.app.secrets" -}}

{{- $svcs := dict -}}

{{- $il := include "groundx.extract.agent.create" . -}}
{{- $es := include "groundx.extract.agent.existingSecret" . -}}
{{- $ak := include "groundx.extract.agent.apiKey" . -}}
{{- $st := include "groundx.extract.agent.serviceType" . -}}
{{- if and (eq $il "true") (eq $es "false") (or (ne $st "bedrock") (ne $ak "")) -}}
{{- $_ := set $svcs "extract.agent" "extract.agent" -}}
{{- end -}}

{{- $sak := include "groundx.summary.apiKey" . -}}
{{- $ses := include "groundx.summary.existingSecret" . -}}
{{- $gxc := include "groundx.groundx.create" . -}}
{{- if and (eq $gxc "true") (ne $sak "") (eq $ses "false") -}}
{{- $_ := set $svcs "summary" "summary" -}}
{{- end -}}

{{- $cp := include "groundx.cache.password" . -}}
{{- $ce := include "groundx.cache.existingSecret" . | trim -}}
{{- if and (ne $cp "") (eq $ce "false") -}}
{{- $_ := set $svcs "cache" "cache" -}}
{{- end -}}

{{- $is := include "groundx.extract.save.create" . -}}
{{- $eg := include "groundx.extract.save.existingSecret" . -}}
{{- $gc := include "groundx.extract.save.gcpCredentials" . -}}
{{- if and (eq $is "true") (eq $eg "false") (ne $gc "") -}}
{{- $_ := set $svcs "extract.save" "extract.save" -}}
{{- end -}}

{{- $admApi := include "groundx.admin.apiKey" . -}}
{{- $admUser := include "groundx.admin.username" . -}}
{{- $admEs := include "groundx.admin.existingSecret" . -}}
{{- if and (or (ne $admApi "") (ne $admUser "")) (eq $admEs "false") -}}
{{- $_ := set $svcs "admin" "admin" -}}
{{- end -}}

{{- $wr := include "groundx.workspace.create" . -}}
{{- $wrs := include "groundx.workspace.existingSecret" . -}}
{{- $wrt := include "groundx.workspace.token" . -}}
{{- $wrg := include "groundx.workspace.github.privateKeyPem" . -}}
{{- $wrl := include "groundx.workspace.gitlab.token" . -}}
{{- if and (eq $wr "true") (eq $wrs "") (ne $wrt "") -}}
{{- $_ := set $svcs "workspace" "workspace" -}}
{{- end -}}
{{- if and (eq $wr "true") (ne $wrg "") -}}
{{- $_ := set $svcs "workspace.github" "workspace.github" -}}
{{- end -}}
{{- if and (eq $wr "true") (ne $wrl "") -}}
{{- $_ := set $svcs "workspace.gitlab" "workspace.gitlab" -}}
{{- end -}}

{{- $svcs | toYaml -}}

{{- end }}
