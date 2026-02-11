{{- define "groundx.layout.process.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- $df := include "groundx.node.cpuMemory" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.process.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-process" $svc }}
{{- end }}

{{- define "groundx.layout.process.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.process.batchSize" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "batchSize" 40 $in }}
{{- end }}

{{- define "groundx.layout.process.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.process.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.layout.process.throughput" -}}
{{- $rep := (include "groundx.layout.process.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.process.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.process.hpa" -}}
{{- $ic := include "groundx.layout.process.create" . -}}
{{- $rep := (include "groundx.layout.process.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.layout.process.serviceName" .) -}}
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

{{- define "groundx.layout.process.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "queue" "process_queue" $in }}
{{- end }}

{{- define "groundx.layout.process.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "process" dict $b -}}
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
  {{- $_ := set $in "threshold" 0.8 -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $_ := set $in "throughput" 10 -}}
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

{{- define "groundx.layout.process.serviceAccountName" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.layout.process.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.process.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.process.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- $rep := (include "groundx.layout.process.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layout.process.serviceAccountName" . -}}
{{- $cfg := dict
  "celery"    ("document.celery_process")
  "image"     (include "groundx.layout.process.image" .)
  "mapPrefix" ("layout")
  "name"      (include "groundx.layout.process.serviceName" .)
  "node"      (include "groundx.layout.process.node" .)
  "pull"      (include "groundx.layout.process.imagePullPolicy" .)
  "queue"     (include "groundx.layout.process.queue" .)
  "replicas"  ($rep)
  "service"   (include "groundx.layout.serviceName" .)
  "threads"   (include "groundx.layout.process.threads" .)
  "workers"   (include "groundx.layout.process.workers" .)
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
