{{- define "groundx.summary.inference.node" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $df := include "groundx.node.gpuSummary" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.summary.inference.serviceName" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.summary.inference.create" -}}
{{- $is := include "groundx.summary.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.summary.inference.containerPort" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summary.inference.deviceType" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.summary.inference.deviceUtilize" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "deviceUtilize" 0.48 $in) }}
{{- end }}

{{- define "groundx.summary.inference.model.dataType" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $md := dig "model" dict $in -}}
{{ (dig "dataType" "bfloat16" $md) }}
{{- end }}

{{- define "groundx.summary.inference.image" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/summary-inference:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.summary.inference.imagePullPolicy" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in) }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.summary.inference.target.default" -}}
0.8
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.summary.inference.threshold.default" -}}
1600
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.summary.inference.throughput.default" -}}
1600
{{- end }}

{{- define "groundx.summary.inference.threshold" -}}
{{- $rep := (include "groundx.summary.inference.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.summary.inference.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.summary.inference.throughput" -}}
{{- $rep := (include "groundx.summary.inference.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.summary.inference.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.summary.inference.hpa" -}}
{{- $ic := include "groundx.summary.inference.create" . -}}
{{- $rep := (include "groundx.summary.inference.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.summary.inference.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:inference" $name)
  "name"         $name
  "replicas"     $rep
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.summary.inference.model.maxInputTokens" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $md := dig "model" dict $in -}}
{{ (dig "maxInputTokens" 100000 $md) }}
{{- end }}

{{- define "groundx.summary.inference.model.maxOutputTokens" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $md := dig "model" dict $in -}}
{{ (dig "maxOutputTokens" 4096 $md) }}
{{- end }}

{{- define "groundx.summary.inference.model.maxRequests" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $md := dig "model" dict $in -}}
{{ (dig "maxRequests" 1 $md) }}
{{- end }}

{{- define "groundx.summary.inference.model.name" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $md := dig "model" dict $in -}}
{{ (dig "name" "google/gemma-3-4b-it" $md) }}
{{- end }}

{{- define "groundx.summary.inference.model.swapSpace" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $md := dig "model" dict $in -}}
{{ (dig "swapSpace" 16 $md) }}
{{- end }}

{{- define "groundx.summary.inference.pvc" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $pvc := dig "pvc" dict $in -}}

{{- $defaults := dict
  "access"   "ReadWriteOnce"
  "capacity" "20Gi"
  "class"    (include "groundx.pvClass" .)
  "name"     (printf "%s-model" (include "groundx.summary.serviceName" .))
-}}

{{ mergeOverwrite $defaults $pvc | toYaml }}
{{- end }}

{{- define "groundx.summary.inference.queue" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "queue" "summary_inference_queue" $in) }}
{{- end }}

{{- define "groundx.summary.inference.replicas" -}}
{{- $b := .Values.summary | default dict -}}
{{- $c := dig "inference" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- $chp := include "groundx.cluster.hpa" . -}}
{{- if not $in }}
  {{- $in = dict -}}
{{- end }}
{{- if not (hasKey $in "cooldown") -}}
  {{- $_ := set $in "cooldown" (include "groundx.hpa.cooldown" .) -}}
{{- end -}}
{{- if not (hasKey $in "hpa") -}}
  {{- $_ := set $in "hpa" $chp -}}
{{- end -}}
{{- if not (hasKey $in "target") -}}
  {{- $_ := set $in "target" (include "groundx.summary.inference.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.summary.inference.threads" . | int) -}}
  {{- $workers := (include "groundx.summary.inference.workers" . | int) -}}
  {{- $dflt := (include "groundx.summary.inference.throughput.default" . | int) -}}
  {{- $_ := set $in "throughput" (mul $dflt $threads $workers) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (dig "throughput" 0 $in) -}}
{{- end -}}
{{- if not (hasKey $in "min") -}}
  {{- if hasKey $in "desired" -}}
    {{- $_ := set $in "min" (dig "desired" 1 $in) -}}
  {{- else -}}
    {{- $_ := set $in "min" 1 -}}
  {{- end -}}
{{- end -}}
{{- if not (hasKey $in "desired") -}}
  {{- $_ := set $in "desired" 1 -}}
{{- end -}}
{{- if not (hasKey $in "max") -}}
  {{- $_ := set $in "max" 32 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.summary.inference.runtimeClassName" -}}
{{- $b := .Values.summary | default dict -}}
{{- $ct := include "groundx.clusterType" . -}}
{{- $in := dig "inference" dict $b -}}
{{- if eq $ct "aks" -}}
{{ dig "runtimeClassName" "nvidia-container-runtime" $in }}
{{- else -}}
{{ dig "runtimeClassName" "" $in }}
{{- end -}}
{{- end }}

{{- define "groundx.summary.inference.serviceAccountName" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.summary.inference.swapSpace" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "swapSpace" 16 $in) }}
{{- end }}

{{- define "groundx.summary.inference.threads" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.summary.inference.updateStrategy" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "updateStrategy" "" $in }}
{{- end }}

{{- define "groundx.summary.inference.workers" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.summary.inference.settings" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $rep := (include "groundx.summary.inference.replicas" . | fromYaml) -}}
{{- $rt := include "groundx.summary.inference.runtimeClassName" . -}}
{{- $san := include "groundx.summary.inference.serviceAccountName" . -}}
{{- $cfg := dict
  "baseName"       ($svc)
  "cfg"            (printf "%s-config-py-map" $svc)
  "image"          (include "groundx.summary.inference.image" .)
  "mapPrefix"      ("summary")
  "modelParts"     ("00 01 02 03 04")
  "modelVersion"   ("g34b")
  "name"           (include "groundx.summary.inference.serviceName" .)
  "node"           (include "groundx.summary.inference.node" .)
  "port"           (include "groundx.summary.inference.containerPort" .)
  "pull"           (include "groundx.summary.inference.imagePullPolicy" .)
  "pvc"            (include "groundx.summary.inference.pvc" . | fromYaml)
  "replicas"       ($rep)
  "supervisord"    (printf "%s-inference-supervisord-conf-map" $svc)
  "updateStrategy" (include "groundx.summary.inference.updateStrategy" .)
  "workingDir"     ("/workspace")
-}}
{{- if ne $rt "" -}}
  {{- $_ := set $cfg "runtimeClassName" $rt -}}
{{- end -}}
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