{{- define "groundx.workspace.cleanup.node" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{ coalesce (dig "node" "" $in) (include "groundx.workspace.node" .) }}
{{- end }}

{{- define "groundx.workspace.cleanup.serviceName" -}}
{{- $svc := include "groundx.workspace.serviceName" . -}}
{{ printf "%s-cleanup" $svc }}
{{- end }}

{{- define "groundx.workspace.cleanup.metricName" -}}
{{ include "groundx.workspace.cleanup.serviceName" . }}
{{- end }}

{{- define "groundx.workspace.cleanup.create" -}}
{{- $is := include "groundx.workspace.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" true $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.workspace.cleanup.target.default" -}}
1
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.workspace.cleanup.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.workspace.cleanup.throughput.default" -}}
9000
{{- end }}

{{- define "groundx.workspace.cleanup.threshold" -}}
{{- $rep := (include "groundx.workspace.cleanup.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.workspace.cleanup.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.workspace.cleanup.throughput" -}}
{{- $rep := (include "groundx.workspace.cleanup.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.workspace.cleanup.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.workspace.cleanup.hpa" -}}
{{- $ic := include "groundx.workspace.cleanup.create" . -}}
{{- $rep := (include "groundx.workspace.cleanup.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := include "groundx.workspace.cleanup.serviceName" . -}}
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

{{- define "groundx.workspace.cleanup.image" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/workspace-runner:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) (dig "image" "" $b) (include "groundx.workspace.api.image" .) $fallback -}}
{{- end }}

{{- define "groundx.workspace.cleanup.imagePullPolicy" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{ coalesce (dig "imagePullPolicy" "" $in) (dig "imagePullPolicy" "" $b) (include "groundx.workspace.api.imagePullPolicy" .) }}
{{- end }}

{{- define "groundx.workspace.cleanup.queue" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{ dig "queue" "cleanup_queue" $in }}
{{- end }}

{{- define "groundx.workspace.cleanup.replicas" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $c := dig "cleanup" dict $b -}}
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
  {{- $_ := set $in "target" (include "groundx.workspace.cleanup.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.workspace.cleanup.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.workspace.cleanup.threads" . | int) -}}
  {{- $workers := (include "groundx.workspace.cleanup.workers" . | int) -}}
  {{- $dflt := (include "groundx.workspace.cleanup.throughput.default" . | int) -}}
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
  {{- $_ := set $in "max" 96 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.workspace.cleanup.serviceAccountName" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.workspace.cleanup.threads" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.workspace.cleanup.workers" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.workspace.cleanup.settings" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "cleanup" dict $b -}}
{{- $rep := (include "groundx.workspace.cleanup.replicas" . | fromYaml) -}}
{{- $san := include "groundx.workspace.cleanup.serviceAccountName" . -}}
{{- $data := dict -}}
{{- if or (ne (include "groundx.workspace.existingSecret" .) "") (ne (include "groundx.workspace.token" .) "") -}}
{{- $_ := set $data (include "groundx.workspace.secretName" .) (include "groundx.workspace.secretName" .) -}}
{{- end -}}
{{- if ne (include "groundx.workspace.github.privateKeyPem" .) "" -}}
{{- $_ := set $data (include "groundx.workspace.githubSecretName" .) (include "groundx.workspace.githubSecretName" .) -}}
{{- end -}}
{{- if ne (include "groundx.workspace.gitlab.token" .) "" -}}
{{- $_ := set $data (include "groundx.workspace.gitlabSecretName" .) (include "groundx.workspace.gitlabSecretName" .) -}}
{{- end -}}
{{- $cfg := dict
  "celery"       ("celery_app")
  "dependencies" (dict "cache" "cache" "db" "db")
  "image"        (include "groundx.workspace.cleanup.image" .)
  "mapPrefix"    (include "groundx.workspace.serviceName" .)
  "name"         (include "groundx.workspace.cleanup.serviceName" .)
  "node"         (include "groundx.workspace.cleanup.node" .)
  "pull"         (include "groundx.workspace.cleanup.imagePullPolicy" .)
  "queue"        (include "groundx.workspace.cleanup.queue" .)
  "replicas"     ($rep)
  "service"      (include "groundx.workspace.serviceName" .)
  "threads"      (include "groundx.workspace.cleanup.threads" .)
  "volumeMounts" (include "groundx.workspace.volumeMounts" . | fromYamlArray)
  "volumes"      (include "groundx.workspace.volumes" . | fromYamlArray)
  "workers"      (include "groundx.workspace.cleanup.workers" .)
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
