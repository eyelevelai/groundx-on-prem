{{- define "groundx.layout.ocr.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-ocr" $svc }}
{{- end }}

{{- define "groundx.layout.ocr.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.ocr.credentials" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{ dig "credentials" "" $in }}
{{- end }}

{{- define "groundx.layout.ocr.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) (include "groundx.layout.process.serviceName" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.layout.ocr.project" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{ dig "project" "" $in }}
{{- end }}

{{- define "groundx.layout.ocr.pull" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.layout.ocr.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{ dig "queue" "ocr_queue" $in }}
{{- end }}

{{- define "groundx.layout.ocr.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.ocr.type" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{ dig "type" "tesseract" $in }}
{{- end }}

{{- define "groundx.layout.ocr.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.ocr.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := (dig "ocr" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "name"         (include "groundx.layout.ocr.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.ocr.image" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.ocr.pull" .) -}}
{{- $_ := set $cfg "queue"        (include "groundx.layout.ocr.queue" .) -}}
{{- $_ := set $cfg "threads"      (include "groundx.layout.ocr.threads" .) -}}
{{- $_ := set $cfg "workers"      (include "groundx.layout.ocr.workers" .) -}}
{{- if and (hasKey $in "replicas") (not (empty (get $in "replicas"))) -}}
  {{- $_ := set $cfg "replicas" (get $in "replicas") -}}
{{- end -}}
{{- if and (hasKey $in "resources") (not (empty (get $in "resources"))) -}}
  {{- $_ := set $cfg "resources" (get $in "resources") -}}
{{- end -}}
{{- if and (hasKey $in "securityContext") (not (empty (get $in "securityContext"))) -}}
  {{- $_ := set $cfg "securityContext" (get $in "securityContext") -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}
