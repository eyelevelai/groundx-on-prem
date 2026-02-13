{{- define "groundx.extract.download.node" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.extract.download.serviceName" -}}
{{- $svc := include "groundx.extract.serviceName" . -}}
{{ printf "%s-download" $svc }}
{{- end }}

{{- define "groundx.extract.download.create" -}}
{{- $is := include "groundx.extract.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.extract.download.image" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/extract:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.extract.download.imagePullPolicy" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.extract.download.target.default" -}}
0.8
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.extract.download.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.extract.download.throughput.default" -}}
30000
{{- end }}

{{- define "groundx.extract.download.threshold" -}}
{{- $rep := (include "groundx.extract.download.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.download.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.download.throughput" -}}
{{- $rep := (include "groundx.extract.download.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.download.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.download.hpa" -}}
{{- $ic := include "groundx.extract.download.create" . -}}
{{- $rep := (include "groundx.extract.download.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.extract.download.serviceName" .) -}}
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

{{- define "groundx.extract.download.queue" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{ dig "queue" "download_queue" $in }}
{{- end }}

{{- define "groundx.extract.download.replicas" -}}
{{- $b := .Values.extract | default dict -}}
{{- $c := dig "download" dict $b -}}
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
  {{- $_ := set $in "target" (include "groundx.extract.download.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.extract.download.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.extract.download.threads" . | int) -}}
  {{- $workers := (include "groundx.extract.download.workers" . | int) -}}
  {{- $dflt := (include "groundx.extract.download.throughput.default" . | int) -}}
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

{{- define "groundx.extract.download.serviceAccountName" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.extract.download.threads" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.extract.download.workers" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.extract.download.settings" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "download" dict $b -}}
{{- $rep := (include "groundx.extract.download.replicas" . | fromYaml) -}}
{{- $san := include "groundx.extract.download.serviceAccountName" . -}}
{{- $data := dict
  (include "groundx.extract.save.secretName" .) (include "groundx.extract.save.secretName" .)
-}}
{{- $apiKey := include "groundx.extract.agent.apiKey" . -}}
{{- if ne $apiKey "" -}}
{{- $_ := set $data (include "groundx.extract.agent.secretName" .) (include "groundx.extract.agent.secretName" .) -}}
{{- end -}}
{{- $cfg := dict
  "celery"     ("celery_agents")
  "dependencies" (dict
    "extract" "extract"
  )
  "fileDomain" (include "groundx.extract.file.serviceDependency" .)
  "filePort"   (include "groundx.extract.file.port" .)
  "image"      (include "groundx.extract.download.image" .)
  "mapPrefix"  ("extract")
  "name"       (include "groundx.extract.download.serviceName" .)
  "node"       (include "groundx.extract.download.node" .)
  "pull"       (include "groundx.extract.download.imagePullPolicy" .)
  "queue"      (include "groundx.extract.download.queue" .)
  "replicas"   ($rep)
  "secrets"    ($data)
  "service"    (include "groundx.extract.serviceName" .)
  "threads"    (include "groundx.extract.download.threads" .)
  "workers"    (include "groundx.extract.download.workers" .)
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
