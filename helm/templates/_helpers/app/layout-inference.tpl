{{- define "groundx.layout.inference.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $df := include "groundx.node.gpuLayout" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.inference.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.layout.inference.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.containerPort" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layout.inference.deviceType" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.layout.inference.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-inference:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.inference.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.layout.inference.target.default" -}}
1
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.layout.inference.threshold.default" -}}
20000
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.layout.inference.throughput.default" -}}
60000
{{- end }}

{{- define "groundx.layout.inference.threshold" -}}
{{- $rep := (include "groundx.layout.inference.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.inference.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.throughput" -}}
{{- $rep := (include "groundx.layout.inference.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.inference.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.hpa" -}}
{{- $ic := include "groundx.layout.inference.create" . -}}
{{- $rep := (include "groundx.layout.inference.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.layout.inference.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:inference" $name)
  "name"         $name
  "replicas"     $rep
  "throughput"   (printf "%s:throughput" $name)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.layout.inference.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "queue" "layout_queue" $in) }}
{{- end }}

{{- define "groundx.layout.inference.replicas" -}}
{{- $b := .Values.layout | default dict -}}
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
  {{- $_ := set $in "target" (include "groundx.layout.inference.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.layout.inference.threads" . | int) -}}
  {{- $workers := (include "groundx.layout.inference.workers" . | int) -}}
  {{- $dflt := (include "groundx.layout.inference.throughput.default" . | int) -}}
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
  {{- $_ := set $in "max" 16 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.inference.serviceAccountName" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.layout.inference.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "threads" 6 $in }}
{{- end }}

{{- define "groundx.layout.inference.updateStrategy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "updateStrategy" "" $in }}
{{- end }}

{{- define "groundx.layout.inference.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.inference.settings" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $rep := (include "groundx.layout.inference.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layout.inference.serviceAccountName" . -}}
{{- $cfg := dict
  "baseName"       ($svc)
  "cfg"            (printf "%s-config-py-map" $svc)
  "execOpts"       ("python /app/init-layout.py &&")
  "fileSync"       ("true")
  "image"          (include "groundx.layout.inference.image" .)
  "mapPrefix"      ("layout")
  "name"           (include "groundx.layout.inference.serviceName" .)
  "node"           (include "groundx.layout.inference.node" .)
  "port"           (include "groundx.layout.inference.containerPort" .)
  "pull"           (include "groundx.layout.inference.imagePullPolicy" .)
  "queue"          (include "groundx.layout.inference.queue" .)
  "replicas"       ($rep)
  "supervisord"    (printf "%s-inference-supervisord-conf-map" $svc)
  "threads"        (include "groundx.layout.inference.threads" .)
  "updateStrategy" (include "groundx.layout.inference.updateStrategy" .)
  "workers"        (include "groundx.layout.inference.workers" .)
  "workingDir"     ("/app")
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
