{{- define "groundx.extract.agent.node" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.extract.agent.serviceName" -}}
{{- $svc := include "groundx.extract.serviceName" . -}}
{{ printf "%s-agent" $svc }}
{{- end }}

{{- define "groundx.extract.agent.create" -}}
{{- $is := include "groundx.extract.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.extract.agent.apiKey" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{ dig "apiKey" (include "groundx.admin.apiKey" .) $in }}
{{- end }}

{{- define "groundx.extract.agent.apiKeyEnv" -}}
GROUNDX_AGENT_API_KEY
{{- end }}

{{- define "groundx.extract.agent.baseUrl" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $dflt := "" -}}
{{- $ic := include "groundx.summary.create" . -}}
{{- $st := include "groundx.extract.agent.serviceType" . -}}
{{- $svcAllowed := or (eq $st "openai") (eq $st "openai-base64") -}}
{{- if and (eq $ic "true") (not $svcAllowed) -}}
{{- $dflt = (include "groundx.summary.api.serviceUrl" .) -}}
{{- end -}}
{{ dig "apiBaseUrl" $dflt $in }}
{{- end }}

{{- define "groundx.extract.agent.existingSecret" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{ dig "existingSecret" false $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.extract.agent.target.default" -}}
0.8
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.extract.agent.threshold.default" -}}
10
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.extract.agent.throughput.default" -}}
3000
{{- end }}

{{- define "groundx.extract.agent.threshold" -}}
{{- $rep := (include "groundx.extract.agent.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.agent.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.agent.throughput" -}}
{{- $rep := (include "groundx.extract.agent.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.agent.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.agent.hpa" -}}
{{- $ic := include "groundx.extract.agent.create" . -}}
{{- $rep := (include "groundx.extract.agent.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.extract.agent.serviceName" .) -}}
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

{{- define "groundx.extract.agent.image" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/extract:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.extract.agent.imagePullPolicy" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.extract.agent.modelId" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $dflt := lower (dig "modelId" "" $in) | trim -}}
{{- $ic := include "groundx.summary.create" . -}}
{{- $st := include "groundx.extract.agent.serviceType" . -}}
{{- $svcAllowed := or (eq $st "openai") (eq $st "openai-base64") -}}
{{- if and (eq $ic "true") (not $svcAllowed) (eq $dflt "") -}}
{{- $dflt = (include "groundx.summary.inference.model.name" .) -}}
{{- end -}}
{{ dig "modelId" $dflt $in }}
{{- end }}

{{- define "groundx.extract.agent.queue" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{ dig "queue" "agent_queue" $in }}
{{- end }}

{{- define "groundx.extract.agent.replicas" -}}
{{- $b := .Values.extract | default dict -}}
{{- $c := dig "agent" dict $b -}}
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
  {{- $_ := set $in "target" (include "groundx.extract.agent.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.extract.agent.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.extract.agent.threads" . | int) -}}
  {{- $workers := (include "groundx.extract.agent.workers" . | int) -}}
  {{- $dflt := (include "groundx.extract.agent.throughput.default" . | int) -}}
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

{{- define "groundx.extract.agent.secretName" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $dflt := printf "%s-secret" (include "groundx.extract.agent.serviceName" .) -}}
{{ dig "secretName" $dflt $in }}
{{- end }}

{{- define "groundx.extract.agent.serviceAccountName" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.extract.agent.serviceType" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{ lower (coalesce (dig "serviceType" "" $in) "eyelevel") | trim }}
{{- end }}

{{- define "groundx.extract.agent.threads" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.extract.agent.workers" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.extract.agent.secrets" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $apiKey := include "groundx.extract.agent.apiKey" . -}}

{{- $cfg := dict
  "name" (include "groundx.extract.agent.secretName" .)
-}}
{{- if ne $apiKey "" -}}
{{- $data := dict
  (include "groundx.extract.agent.apiKeyEnv" .) $apiKey
-}}
{{- $_ := set $cfg "data" $data -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.extract.agent.settings" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "agent" dict $b -}}
{{- $rep := (include "groundx.extract.agent.replicas" . | fromYaml) -}}
{{- $san := include "groundx.extract.agent.serviceAccountName" . -}}
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
  "image"      (include "groundx.extract.agent.image" .)
  "mapPrefix"  ("extract")
  "name"       (include "groundx.extract.agent.serviceName" .)
  "node"       (include "groundx.extract.agent.node" .)
  "pull"       (include "groundx.extract.agent.imagePullPolicy" .)
  "queue"      (include "groundx.extract.agent.queue" .)
  "replicas"   ($rep)
  "secrets"    ($data)
  "service"    (include "groundx.extract.serviceName" .)
  "threads"    (include "groundx.extract.agent.threads" .)
  "workers"    (include "groundx.extract.agent.workers" .)
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
