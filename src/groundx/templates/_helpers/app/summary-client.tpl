{{- define "groundx.summaryClient.node" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.summaryClient.serviceName" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "serviceName" "summary-client" $in }}
{{- end }}

{{- define "groundx.summaryClient.queue" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "queue" "file-summary" $in }}
{{- end }}

{{- define "groundx.summaryClient.create" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.summaryClient.containerPort" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summaryClient.image" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/summary-client:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.summaryClient.imagePullPolicy" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.summaryClient.target.default" -}}
1
{{- end }}

{{- define "groundx.summaryClient.threshold.default" -}}
{{- $sc := include "groundx.summary.create" . -}}
{{- if eq $sc "true" -}}
{{/* tokens per minute per worker per thread */}}
9600
{{- else -}}
{{/* queue message backlog */}}
10
{{- end -}}
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.summaryClient.throughput.default" -}}
{{- $sc := include "groundx.summary.create" . -}}
{{- if eq $sc "true" -}}
9600
{{- else -}}
54000
{{- end -}}
{{- end }}

{{- define "groundx.summaryClient.threshold" -}}
{{- $rep := (include "groundx.summaryClient.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.summaryClient.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.summaryClient.throughput" -}}
{{- $rep := (include "groundx.summaryClient.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.summaryClient.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.summaryClient.hpa" -}}
{{- $ic := include "groundx.summaryClient.create" . -}}
{{- $rep := (include "groundx.summaryClient.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $sc := include "groundx.summary.create" . -}}
{{- $qty := "queue" -}}
{{- if eq $sc "true" -}}
{{- $qty = "inference" -}}
{{- end -}}
{{- $name := (include "groundx.summaryClient.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:%s" $name $qty)
  "name"         $name
  "replicas"     $rep
  "throughput"   (printf "%s:throughput" $name)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.summaryClient.queueSize" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "queueSize" 3 $in }}
{{- end }}

{{- define "groundx.summaryClient.replicas" -}}
{{- $b := .Values.summaryClient | default dict -}}
{{- $in := dig "replicas" dict $b -}}
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
  {{- $_ := set $in "target" (include "groundx.summaryClient.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.summaryClient.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $_ := set $in "throughput" (include "groundx.summaryClient.throughput.default" .) -}}
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

{{- define "groundx.summaryClient.serviceAccountName" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.summaryClient.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.summaryClient.serviceName" . -}}
{{- $port := include "groundx.summaryClient.containerPort" . -}}
{{- if eq $port "80" -}}
{{ printf "http://%s.%s.svc.cluster.local" $name $ns }}
{{- else -}}
{{ printf "http://%s.%s.svc.cluster.local:%v" $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.summaryClient.settings" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{- $rep := (include "groundx.summaryClient.replicas" . | fromYaml) -}}
{{- $san := include "groundx.summaryClient.serviceAccountName" . -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "image"        (include "groundx.summaryClient.image" .)
  "name"         (include "groundx.summaryClient.serviceName" .)
  "node"         (include "groundx.summaryClient.node" .)
  "port"         (include "groundx.summaryClient.containerPort" .)
  "pull"         (include "groundx.summaryClient.imagePullPolicy" .)
  "replicas"     ($rep)
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
