{{- define "groundx.layout.save.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $df := include "groundx.node.cpuMemory" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.save.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-save" $svc }}
{{- end }}

{{- define "groundx.layout.save.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.save.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.save.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.layout.save.target.default" -}}
0.8
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.layout.save.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.layout.save.throughput.default" -}}
20000
{{- end }}

{{- define "groundx.layout.save.threshold" -}}
{{- $rep := (include "groundx.layout.save.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.save.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.save.throughput" -}}
{{- $rep := (include "groundx.layout.save.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.save.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.save.hpa" -}}
{{- $ic := include "groundx.layout.save.create" . -}}
{{- $rep := (include "groundx.layout.save.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.layout.save.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:task" $name)
  "name"         $name
  "replicas"     $rep
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.layout.save.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "queue" "save_queue,celery" $in }}
{{- end }}

{{- define "groundx.layout.save.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "save" dict $b -}}
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
  {{- $_ := set $in "target" (include "groundx.layout.save.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.layout.save.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.layout.save.threads" . | int) -}}
  {{- $workers := (include "groundx.layout.save.workers" . | int) -}}
  {{- $dflt := (include "groundx.layout.save.throughput.default" . | int) -}}
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

{{- define "groundx.layout.save.serviceAccountName" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.layout.save.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.save.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.save.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $rep := (include "groundx.layout.save.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layout.save.serviceAccountName" . -}}
{{- $cfg := dict
  "celery"    ("document.celery_process")
  "image"     (include "groundx.layout.save.image" .)
  "mapPrefix" ("layout")
  "name"      (include "groundx.layout.save.serviceName" .)
  "node"      (include "groundx.layout.save.node" .)
  "pull"      (include "groundx.layout.save.imagePullPolicy" .)
  "queue"     (include "groundx.layout.save.queue" .)
  "replicas"  ($rep)
  "service"   (include "groundx.layout.serviceName" .)
  "threads"   (include "groundx.layout.save.threads" .)
  "workers"   (include "groundx.layout.save.workers" .)
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
