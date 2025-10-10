{{- define "groundx.preProcess.node" -}}
{{- $in := .Values.preProcess | default dict -}}
{{- $df := include "groundx.node.cpuMemory" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.preProcess.serviceName" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "serviceName" "pre-process" $in }}
{{- end }}

{{- define "groundx.preProcess.queue" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "queue" "file-pre-process" $in }}
{{- end }}

{{- define "groundx.preProcess.create" -}}
{{- $in := .Values.preProcess | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.preProcess.containerPort" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.preProcess.image" -}}
{{- $in := .Values.preProcess | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/pre-process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.preProcess.imagePullPolicy" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "imagePullPolicy" "IfNotPresent" $in }}
{{- end }}

{{- define "groundx.preProcess.queueSize" -}}
{{- $in := .Values.preProcess | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.preProcess.replicas" -}}
{{- $b := .Values.preProcess | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.preProcess.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.preProcess.serviceName" . -}}
{{- $port := include "groundx.preProcess.containerPort" . -}}
{{- if eq $port "80" -}}
{{ printf "http://%s.%s.svc.cluster.local" $name $ns }}
{{- else -}}
{{ printf "http://%s.%s.svc.cluster.local:%v" $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.preProcess.settings" -}}
{{- $in := .Values.preProcess | default dict -}}
{{- $rep := (include "groundx.preProcess.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "node"         (include "groundx.preProcess.node" .)
  "replicas"     ($rep)
-}}
{{- $_ := set $cfg "name"         (include "groundx.preProcess.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.preProcess.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.preProcess.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.preProcess.imagePullPolicy" .) -}}
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
