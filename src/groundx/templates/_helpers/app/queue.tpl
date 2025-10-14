{{- define "groundx.queue.node" -}}
{{- $in := .Values.queue | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.queue.serviceName" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "serviceName" "queue" $in }}
{{- end }}

{{- define "groundx.queue.queue" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "queue" "file-update" $in }}
{{- end }}

{{- define "groundx.queue.create" -}}
{{- $in := .Values.queue | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.queue.containerPort" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.queue.image" -}}
{{- $in := .Values.queue | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/queue:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.queue.imagePullPolicy" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
{{- end }}

{{- define "groundx.queue.queueSize" -}}
{{- $in := .Values.queue | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.queue.replicas" -}}
{{- $b := .Values.queue | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.queue.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.queue.serviceName" . -}}
{{- $port := include "groundx.queue.containerPort" . -}}
{{- if eq $port "80" -}}
{{ printf "http://%s.%s.svc.cluster.local" $name $ns }}
{{- else -}}
{{ printf "http://%s.%s.svc.cluster.local:%v" $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.queue.settings" -}}
{{- $in := .Values.queue | default dict -}}
{{- $rep := (include "groundx.queue.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "node"         (include "groundx.queue.node" .)
  "replicas"     ($rep)
-}}
{{- $_ := set $cfg "name"         (include "groundx.queue.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.queue.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.queue.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.queue.imagePullPolicy" .) -}}
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
