{{- define "groundx.extract.save.node" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.extract.save.serviceName" -}}
{{- $svc := include "groundx.extract.serviceName" . -}}
{{ printf "%s-save" $svc }}
{{- end }}

{{- define "groundx.extract.save.create" -}}
{{- $is := include "groundx.extract.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.extract.save.apiKeyEnv" -}}
GCP_CREDENTIALS
{{- end }}

{{- define "groundx.extract.save.driveId" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "driveId" "" $in }}
{{- end }}

{{- define "groundx.extract.save.existingSecret" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "existingSecret" false $in }}
{{- end }}

{{- define "groundx.extract.save.gcpCredentials" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $json := dig "gcpCredentials" "" $in -}}
{{ coalesce $json "" }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.extract.save.target.default" -}}
1
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.extract.save.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.extract.save.throughput.default" -}}
50000
{{- end }}

{{- define "groundx.extract.save.threshold" -}}
{{- $rep := (include "groundx.extract.save.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.save.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.save.throughput" -}}
{{- $rep := (include "groundx.extract.save.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.save.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.save.hpa" -}}
{{- $ic := include "groundx.extract.save.create" . -}}
{{- $rep := (include "groundx.extract.save.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.extract.save.serviceName" .) -}}
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

{{- define "groundx.extract.save.secretName" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $dflt := printf "%s-secret" (include "groundx.extract.save.serviceName" .) -}}
{{ dig "secretName" $dflt $in }}
{{- end }}

{{- define "groundx.extract.save.templateId" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "templateId" "" $in }}
{{- end }}

{{- define "groundx.extract.save.image" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/extract:%s" $repoPrefix $ver -}}
{{ coalesce (dig "image" "" $in) $fallback }}
{{- end }}

{{- define "groundx.extract.save.imagePullPolicy" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.extract.save.queue" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "queue" "save_agents_queue" $in }}
{{- end }}

{{- define "groundx.extract.save.replicas" -}}
{{- $b := .Values.extract | default dict -}}
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
  {{- $_ := set $in "target" (include "groundx.extract.save.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.extract.save.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.extract.save.threads" . | int) -}}
  {{- $workers := (include "groundx.extract.save.workers" . | int) -}}
  {{- $dflt := (include "groundx.extract.save.throughput.default" . | int) -}}
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
  {{- $_ := set $in "max" 24 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.extract.save.secrets" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $gc := include "groundx.extract.save.gcpCredentials" . -}}

{{- $cfg := dict
  "name" (include "groundx.extract.save.secretName" .)
-}}
{{- $data := dict
  (include "groundx.extract.save.apiKeyEnv" .) $gc
-}}
{{- $_ := set $cfg "data" $data -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.extract.save.serviceAccountName" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.extract.save.threads" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.extract.save.workers" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.extract.save.settings" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "save" dict $b -}}

{{- $dpnd := dict
  "extract" "extract"
-}}

{{- $rep := (include "groundx.extract.save.replicas" . | fromYaml) -}}
{{- $san := include "groundx.extract.save.serviceAccountName" . -}}
{{- $data := dict
  (include "groundx.extract.save.secretName" .) (include "groundx.extract.save.secretName" .)
-}}
{{- $apiKey := include "groundx.extract.agent.apiKey" . -}}
{{- if ne $apiKey "" -}}
{{- $_ := set $data (include "groundx.extract.agent.secretName" .) (include "groundx.extract.agent.secretName" .) -}}
{{- end -}}
{{- $cfg := dict
  "celery"       ("celery_agents")
  "dependencies" $dpnd
  "fileDomain"   (include "groundx.extract.file.serviceDependency" .)
  "filePort"     (include "groundx.extract.file.port" .)
  "image"        (include "groundx.extract.save.image" .)
  "mapPrefix"    ("extract")
  "name"         (include "groundx.extract.save.serviceName" .)
  "node"         (include "groundx.extract.save.node" .)
  "pull"         (include "groundx.extract.save.imagePullPolicy" .)
  "queue"        (include "groundx.extract.save.queue" .)
  "replicas"     ($rep)
  "secrets"      ($data)
  "service"      (include "groundx.extract.serviceName" .)
  "threads"      (include "groundx.extract.save.threads" .)
  "workers"      (include "groundx.extract.save.workers" .)
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
