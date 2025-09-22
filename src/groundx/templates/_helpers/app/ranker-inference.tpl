{{- define "groundx.ranker.inference.serviceName" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.ranker.inference.create" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.ranker.inference.deviceType" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.ranker.inference.image" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $svc := include "groundx.ranker.inference.serviceName" . -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) $svc -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.ranker.inference.pull" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.ranker.inference.pvc" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $pvc := (dig "pvc" dict $in) | default dict -}}

{{- $defaults := dict
  "access"   "ReadWriteOnce"
  "capacity" "10Gi"
  "class"    (.Values.pvClass)
  "name"     (printf "%s-model" (include "groundx.ranker.serviceName" .))
-}}

{{ mergeOverwrite $defaults $pvc | toYaml }}
{{- end }}

{{- define "groundx.ranker.inference.queue" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ (dig "queue" "inference_queue" $in) }}
{{- end }}

{{- define "groundx.ranker.inference.threads" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.ranker.inference.workers" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "workers" 14 $in }}
{{- end }}

{{- define "groundx.ranker.inference.settings" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "baseName"     ($svc) -}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "name"         (include "groundx.ranker.inference.serviceName" .) -}}
{{- $_ := set $cfg "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc) -}}
{{- $_ := set $cfg "image"        (include "groundx.ranker.inference.image" .) -}}
{{- $_ := set $cfg "isCelery"     ("true") -}}
{{- $_ := set $cfg "modelParts"   ("00 01 02") -}}
{{- $_ := set $cfg "modelVersion" ("model") -}}
{{- $_ := set $cfg "pvc"          (include "groundx.ranker.inference.pvc" . | fromYaml) -}}
{{- $_ := set $cfg "workingDir"   ("/workspace") -}}
{{- $_ := set $cfg "pull"         (include "groundx.ranker.inference.pull" .) -}}
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