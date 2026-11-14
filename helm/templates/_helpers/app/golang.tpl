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
  "fileAccess"
  "layoutWebhook"
  "preProcess"
  "process"
  "queue"
  "largeFileDeliver"
  "postProcess"
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

{{- define "groundx.golang.defaultGrace" -}}
{{- $table := dict
  "groundx" 150
  "layoutWebhook" 150
  "fileAccess" 150
  "metrics" 150
  "preProcess" 900
  "process" 900
  "queue" 900
  "summaryClient" 900
  "upload" 900
  "largeFileDeliver" 900
  "postProcess" 900
-}}
{{- required (printf "unknown Go service key %q" .) (get $table .) -}}
{{- end }}

{{- define "groundx.golang.gracePeriod" -}}
{{- $default := int (include "groundx.golang.defaultGrace" .key) -}}
{{- int (dig "gracePeriod" $default (.replicas | default dict)) -}}
{{- end }}

{{- define "groundx.golang.drainSeconds" -}}
{{- $grace := int (include "groundx.golang.gracePeriod" .) -}}
{{- int (max 1 (sub $grace 30)) -}}
{{- end }}
