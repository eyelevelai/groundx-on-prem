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

{{/* fraction of threshold */}}
{{- define "groundx.layout.process.target.default" -}}
1
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.layout.process.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.layout.process.throughput.default" -}}
100000
{{- end }}

{{- define "groundx.layout.process.threshold" -}}
{{- $rep := (include "groundx.layout.process.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.process.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
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
  "throughput"   (printf "%s:throughput" $name)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.layout.process.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "queue" "process_queue" $in }}
{{- end }}

{{- define "groundx.layout.process.renderDiskBudgetMi" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "renderDiskBudgetMi" 2048 $in }}
{{- end }}

{{- define "groundx.layout.process.storageMi" -}}
{{- $raw := "" -}}
{{- if or (kindIs "float64" .) (kindIs "int" .) (kindIs "int64" .) -}}
  {{- $raw = printf "%.0f" (float64 .) -}}
{{- else -}}
  {{- $raw = toString . -}}
{{- end -}}
{{- $units := dict
  "Ki" 1024.0
  "Mi" 1048576.0
  "Gi" 1073741824.0
  "Ti" 1099511627776.0
  "Pi" 1125899906842624.0
  "Ei" 1152921504606846976.0
  "k"  1000.0
  "M"  1000000.0
  "G"  1000000000.0
  "T"  1000000000000.0
  "P"  1000000000000000.0
  "E"  1000000000000000000.0
-}}
{{- $mult := 1.0 -}}
{{- $num := $raw -}}
{{- range $suffix, $m := $units -}}
  {{- if hasSuffix $suffix $raw -}}
    {{- $num = trimSuffix $suffix $raw -}}
    {{- $mult = $m -}}
  {{- end -}}
{{- end -}}
{{- if not (regexMatch "^[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?$" $num) -}}
  {{- fail (printf "%q is not a recognized Kubernetes storage quantity (expected a plain byte count, exponent form, or a Ki/Mi/Gi/Ti/Pi/Ei/k/M/G/T/P/E suffix)" $raw) -}}
{{- end -}}
{{ divf (mulf ($num | float64) $mult) 1048576.0 }}
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
{{- if not (hasKey $in "target") -}}
  {{- $_ := set $in "target" (include "groundx.layout.process.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.layout.process.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.layout.process.threads" . | int) -}}
  {{- $workers := (include "groundx.layout.process.workers" . | int) -}}
  {{- $dflt := (include "groundx.layout.process.throughput.default" . | int) -}}
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
  {{- $_ := set $in "max" 16 -}}
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

{{- $dpnd := dict
  "file" "file"
-}}

{{- $rep := (include "groundx.layout.process.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layout.process.serviceAccountName" . -}}
{{- $renderMountPath := "/tmp/render" -}}
{{- $renderDiskBudgetMi := (include "groundx.layout.process.renderDiskBudgetMi" . | int) -}}
{{- $renderThreads := (include "groundx.layout.process.threads" . | int) -}}
{{- $renderWorkers := (include "groundx.layout.process.workers" . | int) -}}
{{- if lt $renderWorkers 1 -}}
  {{- fail (printf "layout.process.workers must be at least 1 (got %d)" $renderWorkers) -}}
{{- end -}}
{{- if lt $renderThreads 1 -}}
  {{- fail (printf "layout.process.threads must be at least 1 (got %d)" $renderThreads) -}}
{{- end -}}
{{- $renderDiskMi := add (mul $renderWorkers $renderThreads $renderDiskBudgetMi) 1024 -}}
{{- $cfg := dict
  "celery"       ("document.celery_process")
  "dependencies" $dpnd
  "env"          (dict "TMPDIR" $renderMountPath "LAYOUT_RENDER_DISK_BUDGET_MIB" (toString $renderDiskBudgetMi))
  "image"        (include "groundx.layout.process.image" .)
  "mapPrefix"    ("layout")
  "name"         (include "groundx.layout.process.serviceName" .)
  "node"         (include "groundx.layout.process.node" .)
  "pull"         (include "groundx.layout.process.imagePullPolicy" .)
  "queue"        (include "groundx.layout.process.queue" .)
  "replicas"     ($rep)
  "service"      (include "groundx.layout.serviceName" .)
  "threads"      (include "groundx.layout.process.threads" .)
  "volumeMounts" (list (dict "name" "render-temp" "mountPath" $renderMountPath))
  "volumes"      (list (dict "name" "render-temp" "emptyDir" (dict "sizeLimit" (printf "%dMi" $renderDiskMi))))
  "workers"      (include "groundx.layout.process.workers" .)
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
{{- $renderResources := deepCopy (dig "resources" dict $in) -}}
{{- $renderLimits := dig "limits" dict $renderResources -}}
{{- if hasKey $renderLimits "ephemeral-storage" -}}
  {{- $renderLimitRaw := get $renderLimits "ephemeral-storage" -}}
  {{- $renderLimitMi := include "groundx.layout.process.storageMi" $renderLimitRaw | trim | float64 -}}
  {{- if lt $renderLimitMi (float64 $renderDiskMi) -}}
    {{- fail (printf "layout.process.resources.limits[\"ephemeral-storage\"] (%v) is below the computed ephemeral-storage request of %dMi (workers x threads x layout.process.renderDiskBudgetMi + 1024Mi); raise the limit or lower layout.process.renderDiskBudgetMi, workers, or threads" $renderLimitRaw $renderDiskMi) -}}
  {{- end -}}
{{- end -}}
{{- $renderRequests := deepCopy (dig "requests" dict $renderResources) -}}
{{- $_ := set $renderRequests "ephemeral-storage" (printf "%dMi" $renderDiskMi) -}}
{{- $_ := set $renderResources "requests" $renderRequests -}}
{{- $_ := set $cfg "resources" $renderResources -}}
{{- if and (hasKey $in "securityContext") (not (empty (get $in "securityContext"))) -}}
  {{- $_ := set $cfg "securityContext" (get $in "securityContext") -}}
{{- end -}}
{{- if and (hasKey $in "tolerations") (not (empty (get $in "tolerations"))) -}}
  {{- $_ := set $cfg "tolerations" (get $in "tolerations") -}}
{{- end -}}
{{- if and (hasKey $in "topologySpreadConstraints") (not (empty (get $in "topologySpreadConstraints"))) -}}
  {{- $_ := set $cfg "topologySpreadConstraints" (get $in "topologySpreadConstraints") -}}
{{- end -}}
{{- if hasKey $in "disruptionBudget" -}}
  {{- $_ := set $cfg "disruptionBudget" (get $in "disruptionBudget") -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}
