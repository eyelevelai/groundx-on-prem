{{- define "groundx.golang.home" -}}
{{- $in := .Values.golang | default dict -}}
{{- if eq .Values.imageType "chainguard" -}}
nonroot
{{- else -}}
golang
{{- end -}}
{{- end }}

{{- define "groundx.integration.search.duration" -}}
{{- $b := .Values.integration | default dict -}}
{{- $in := (dig "search" nil $b) | default dict -}}
{{ dig "duration" 3660 $in }}
{{- end }}

{{- define "groundx.integration.search.fileId" -}}
{{- $b := .Values.integration | default dict -}}
{{- $in := (dig "search" nil $b) | default dict -}}
{{ dig "fileId" "ey-mtr6hapxq7d94zigammwir6xz4" $in }}
{{- end }}

{{- define "groundx.integration.search.modelId" -}}
{{- $b := .Values.integration | default dict -}}
{{- $in := (dig "search" nil $b) | default dict -}}
{{ dig "modelId" 1 $in }}
{{- end }}

{{- define "groundx.golang.services" -}}

{{- $svcs := dict -}}

{{- $services := list
  "groundx"
  "layoutWebhook"
  "preProcess"
  "process"
  "queue"
  "summaryClient"
  "upload"
-}}

{{- range $svc := $services }}
  {{- $tpl := printf "groundx.%s.create" $svc -}}
  {{- $il := include $tpl $ -}}
  {{- if eq $il "true" -}}
    {{- $_ := set $svcs $svc $svc -}}
  {{- end -}}
{{- end }}

{{- $svcs | toYaml -}}

{{- end }}
