{{- define "groundx.layout.map.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.map.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-map" $svc }}
{{- end }}

{{- define "groundx.layout.map.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.map.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.map.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.layout.map.target.default" -}}
0.8
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.layout.map.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.layout.map.throughput.default" -}}
30000
{{- end }}

{{- define "groundx.layout.map.threshold" -}}
{{- $rep := (include "groundx.layout.map.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.map.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.map.throughput" -}}
{{- $rep := (include "groundx.layout.map.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.map.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.map.hpa" -}}
{{- $ic := include "groundx.layout.map.create" . -}}
{{- $rep := (include "groundx.layout.map.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.layout.map.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:task" $name)
  "name"         $name
  "replicas"     $rep
  "throughput"   (include "groundx.layout.map.throughput" .)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.layout.map.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "queue" "map_queue" $in }}
{{- end }}

{{- define "groundx.layout.map.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "map" dict $b -}}
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
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.layout.map.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.layout.map.threads" . | int) -}}
  {{- $workers := (include "groundx.layout.map.workers" . | int) -}}
  {{- $dflt := (include "groundx.layout.map.throughput.default" . | int) -}}
  {{- $_ := set $in "throughput" (mul $dflt $threads $workers) -}}
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

{{- define "groundx.layout.map.serviceAccountName" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.layout.map.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.map.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.map.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}

{{- $dpnd := dict -}}

{{- $rep := (include "groundx.layout.map.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layout.map.serviceAccountName" . -}}
{{- $cfg := dict
  "celery"       ("document.celery_process")
  "dependencies" $dpnd
  "image"        (include "groundx.layout.map.image" .)
  "mapPrefix"    ("layout")
  "name"         (include "groundx.layout.map.serviceName" .)
  "node"         (include "groundx.layout.map.node" .)
  "pull"         (include "groundx.layout.map.imagePullPolicy" .)
  "queue"        (include "groundx.layout.map.queue" .)
  "replicas"     ($rep)
  "service"      (include "groundx.layout.serviceName" .)
  "threads"      (include "groundx.layout.map.threads" .)
  "workers"      (include "groundx.layout.map.workers" .)
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
