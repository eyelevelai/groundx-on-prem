{{- define "groundx.app.ingress" -}}

{{- $svcs := dict -}}

{{ $gx := include "groundx.groundx.ingress" . | fromYaml }}
{{- $gxe := dig "enabled" "true" $gx | toString -}}
{{- if eq $gxe "true" -}}
{{- $_ := set $svcs "groundx" "groundx" -}}
{{- end -}}

{{- $services := list
  "file"
  "extract.api"
  "layout.api"
  "layoutWebhook"
  "ranker.api"
  "summary.api"
  "workspace.api"
-}}

{{- range $svc := $services }}
  {{- $tpl := printf "groundx.%s.ingress" $svc -}}
  {{- $gx := include $tpl $ | fromYaml -}}
  {{- $enabled := dig "enabled" "false" $gx | toString -}}
  {{- if eq $enabled "true" -}}
    {{- $_ := set $svcs $svc $svc -}}
    {{- if hasSuffix ".api" $svc -}}
      {{- $data := dig "data" dict $gx -}}
      {{- $paths := dig "paths" list $data -}}
      {{- if or (not $paths) (eq (len $paths) 0) -}}
        {{- $createKey := printf "groundx.%s.create" $svc -}}
        {{- $isCreated := include $createKey $ -}}
        {{- if eq $isCreated "false" -}}
          {{- fail (printf "%s.ingress is enabled but %s is not created; enable %s or remove the ingress" $svc $svc $svc) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end }}

{{- $svcs | toYaml -}}

{{- end }}
