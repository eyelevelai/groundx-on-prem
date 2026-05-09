{{- define "groundx.workspace.command.node" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{ coalesce (dig "node" "" $in) (include "groundx.workspace.node" .) }}
{{- end }}

{{- define "groundx.workspace.command.serviceName" -}}
{{- $svc := include "groundx.workspace.serviceName" . -}}
{{ printf "%s-command" $svc }}
{{- end }}

{{- define "groundx.workspace.command.metricName" -}}
{{ include "groundx.workspace.command.serviceName" . }}
{{- end }}

{{- define "groundx.workspace.command.create" -}}
{{- $is := include "groundx.workspace.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" true $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.workspace.command.target.default" -}}
1
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.workspace.command.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.workspace.command.throughput.default" -}}
9000
{{- end }}

{{- define "groundx.workspace.command.threshold" -}}
{{- $rep := (include "groundx.workspace.command.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.workspace.command.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.workspace.command.throughput" -}}
{{- $rep := (include "groundx.workspace.command.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.workspace.command.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.workspace.command.hpa" -}}
{{- $ic := include "groundx.workspace.command.create" . -}}
{{- $rep := (include "groundx.workspace.command.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := include "groundx.workspace.command.serviceName" . -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 10)
  "enabled"      $enabled
  "metric"       (printf "%s:task" $name)
  "name"         $name
  "replicas"     $rep
  "throughput"   (printf "%s:throughput" $name)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.workspace.command.image" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/workspace-runner:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) (dig "image" "" $b) (include "groundx.workspace.api.image" .) $fallback -}}
{{- end }}

{{- define "groundx.workspace.command.imagePullPolicy" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{ coalesce (dig "imagePullPolicy" "" $in) (dig "imagePullPolicy" "" $b) (include "groundx.workspace.api.imagePullPolicy" .) }}
{{- end }}

{{- define "groundx.workspace.command.queue" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{ dig "queue" "command_queue" $in }}
{{- end }}

{{- define "groundx.workspace.command.replicas" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $c := dig "command" dict $b -}}
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
  {{- $_ := set $in "target" (include "groundx.workspace.command.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.workspace.command.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.workspace.command.threads" . | int) -}}
  {{- $workers := (include "groundx.workspace.command.workers" . | int) -}}
  {{- $dflt := (include "groundx.workspace.command.throughput.default" . | int) -}}
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
  {{- $_ := set $in "max" 8 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.workspace.command.serviceAccountName" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.workspace.command.threads" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.workspace.command.workers" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.workspace.command.settings" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "command" dict $b -}}
{{- $rep := (include "groundx.workspace.command.replicas" . | fromYaml) -}}
{{- $san := include "groundx.workspace.command.serviceAccountName" . -}}
{{- $data := dict -}}
{{- if or (ne (include "groundx.workspace.existingSecret" .) "") (ne (include "groundx.workspace.token" .) "") -}}
{{- $_ := set $data (include "groundx.workspace.secretName" .) (include "groundx.workspace.secretName" .) -}}
{{- end -}}
{{- if ne (include "groundx.workspace.github.privateKeyPem" .) "" -}}
{{- $_ := set $data (include "groundx.workspace.githubSecretName" .) (include "groundx.workspace.githubSecretName" .) -}}
{{- end -}}
{{- $cfg := dict
  "celery"       ("celery_app")
  "dependencies" (dict "cache" "cache" "db" "db")
  "image"        (include "groundx.workspace.command.image" .)
  "mapPrefix"    (include "groundx.workspace.serviceName" .)
  "name"         (include "groundx.workspace.command.serviceName" .)
  "node"         (include "groundx.workspace.command.node" .)
  "pull"         (include "groundx.workspace.command.imagePullPolicy" .)
  "queue"        (include "groundx.workspace.command.queue" .)
  "replicas"     ($rep)
  "service"      (include "groundx.workspace.serviceName" .)
  "threads"      (include "groundx.workspace.command.threads" .)
  "volumeMounts" (include "groundx.workspace.volumeMounts" . | fromYamlArray)
  "volumes"      (include "groundx.workspace.volumes" . | fromYamlArray)
  "workers"      (include "groundx.workspace.command.workers" .)
-}}
{{- if gt (len $data) 0 }}{{- $_ := set $cfg "secrets" $data -}}{{- end -}}
{{- if hasKey $rep "gracePeriod" -}}
  {{- $_ := set $cfg "gracePeriod" (dig "gracePeriod" nil $rep) -}}
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
