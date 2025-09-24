{{- define "groundx.summary.inference.serviceName" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.summary.inference.create" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.summary.inference.containerPort" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summary.inference.deviceType" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.summary.inference.deviceUtilize" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ (dig "deviceUtilize" 0.9 $in) }}
{{- end }}

{{- define "groundx.summary.inference.image" -}}
{{- $b := .Values.summary | default dict -}}
{{- $svc := include "groundx.summary.inference.serviceName" . -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{- $bs := printf "%s/eyelevel/%s" (include "groundx.imageRepository" .) $svc -}}
{{ printf "%s:%s" (dig "repository" $bs $img) (dig "repository" "latest" $img) }}
{{- end }}

{{- define "groundx.summary.inference.pull" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $img := (dig "image" nil $in) | default dict -}}
{{ (dig "pull" "Always" $img) }}
{{- end }}

{{- define "groundx.summary.inference.pvc" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $pvc := (dig "pvc" dict $in) | default dict -}}

{{- $defaults := dict
  "access"   "ReadWriteOnce"
  "capacity" "20Gi"
  "class"    (.Values.pvClass)
  "name"     (printf "%s-model" (include "groundx.summary.serviceName" .))
-}}

{{ mergeOverwrite $defaults $pvc | toYaml }}
{{- end }}

{{- define "groundx.summary.inference.queue" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ (dig "queue" "summary_inference_queue" $in) }}
{{- end }}

{{- define "groundx.summary.inference.threads" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.summary.inference.workers" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.summary.inference.settings" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := (dig "inference" nil $b) | default dict -}}
{{- $cfg := dict -}}
{{- $_ := set $cfg "baseName"     ($svc) -}}
{{- $_ := set $cfg "cfg"          (printf "%s-config-py-map" $svc) -}}
{{- $_ := set $cfg "name"         (include "groundx.summary.inference.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.summary.inference.image" .) -}}
{{- $_ := set $cfg "modelParts"   ("00 01 02 03 04") -}}
{{- $_ := set $cfg "modelVersion" ("g34b") -}}
{{- $_ := set $cfg "port"         (include "groundx.summary.inference.containerPort" .) -}}
{{- $_ := set $cfg "pvc"          (include "groundx.summary.inference.pvc" . | fromYaml) -}}
{{- $_ := set $cfg "supervisord"  (printf "%s-inference-supervisord-conf-map" $svc) -}}
{{- $_ := set $cfg "workingDir"   ("/workspace") -}}
{{- $_ := set $cfg "pull"         (include "groundx.summary.inference.pull" .) -}}
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