{{- define "groundx.ranker.inference.node" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $df := include "groundx.node.gpuRanker" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.ranker.inference.serviceName" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.ranker.inference.create" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $io := include "groundx.ingestOnly" . -}}
{{- if eq $io "true" -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.ranker.inference.deviceType" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.ranker.inference.image" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/ranker-inference:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.ranker.inference.imagePullPolicy" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.ranker.inference.pvc" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $pvc := dig "pvc" dict $in -}}

{{- $defaults := dict
  "access"   "ReadWriteOnce"
  "capacity" "10Gi"
  "class"    (include "groundx.pvClass" .)
  "name"     (printf "%s-model" (include "groundx.ranker.serviceName" .))
-}}

{{ mergeOverwrite $defaults $pvc | toYaml }}
{{- end }}

{{- define "groundx.ranker.inference.queue" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "queue" "inference_queue" $in) }}
{{- end }}

{{- define "groundx.ranker.inference.replicas" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $c := dig "inference" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.ranker.inference.serviceAccountName" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.ranker.inference.threads" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.ranker.inference.workers" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "workers" 14 $in }}
{{- end }}

{{- define "groundx.ranker.inference.settings" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $rep := (include "groundx.ranker.inference.replicas" . | fromYaml) -}}
{{- $san := include "groundx.ranker.inference.serviceAccountName" . -}}
{{- $cfg := dict
  "baseName"     ($svc)
  "celery"       ("ranker.celery.appSearch")
  "cfg"          (printf "%s-config-py-map" $svc)
  "image"        (include "groundx.ranker.inference.image" .)
  "mapPrefix"    ("ranker")
  "modelParts"   ("00 01 02")
  "modelVersion" ("model")
  "name"         (include "groundx.ranker.inference.serviceName" .)
  "node"         (include "groundx.ranker.inference.node" .)
  "pull"         (include "groundx.ranker.inference.imagePullPolicy" .)
  "pvc"          (include "groundx.ranker.inference.pvc" . | fromYaml)
  "replicas"     ($rep)
  "supervisord"  (printf "%s-inference-supervisord-conf-map" $svc)
  "workingDir"   ("/workspace")
-}}
{{- if and $san (ne $san "") -}}
  {{- $_ := set $cfg "serviceAccountName" $san -}}
{{- end -}}
{{- if and (hasKey $in "affinity") (not (empty (get $in "affinity"))) -}}
  {{- $_ := set $cfg "affinity" (get $in "affinity") -}}
{{- end -}}
{{- if and (hasKey $in "annotations") (not (empty (get $in "annotations"))) -}}
  {{- $_ := set $cfg "annotations" (get $in "annotations") -}}
{{- end -}}
{{- if and (hasKey $in "containerSecurityContext") (not (empty (get $in "containerSecurityContext"))) -}}
  {{- $_ := set $cfg "containerSecurityContext" (get $in "containerSecurityContext") -}}
{{- end -}}
{{- if and (hasKey $in "labels") (not (empty (get $in "labels"))) -}}
  {{- $_ := set $cfg "labels" (get $in "labels") -}}
{{- end -}}
{{- if and (hasKey $in "nodeSelector") (not (empty (get $in "nodeSelector"))) -}}
  {{- $_ := set $cfg "nodeSelector" (get $in "nodeSelector") -}}
{{- end -}}
{{- if and (hasKey $in "resources") (not (empty (get $in "resources"))) -}}
  {{- $_ := set $cfg "resources" (get $in "resources") -}}
{{- end -}}
{{- if and (hasKey $in "securityContext") (not (empty (get $in "securityContext"))) -}}
  {{- $_ := set $cfg "securityContext" (get $in "securityContext") -}}
{{- end -}}
{{- if and (hasKey $in "tolerations") (not (empty (get $in "tolerations"))) -}}
  {{- $_ := set $cfg "tolerations" (get $in "tolerations") -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}