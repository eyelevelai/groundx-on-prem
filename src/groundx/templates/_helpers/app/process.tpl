{{- define "groundx.process.node" -}}
{{- $in := .Values.process | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.process.serviceName" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "serviceName" "process" $in }}
{{- end }}

{{- define "groundx.process.queue" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "queue" "file-process" $in }}
{{- end }}

{{- define "groundx.process.create" -}}
{{- $in := .Values.process | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.process.containerPort" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.process.image" -}}
{{- $in := .Values.process | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.process.imagePullPolicy" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
{{- end }}

{{- define "groundx.process.queueSize" -}}
{{- $in := .Values.process | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.process.replicas" -}}
{{- $b := .Values.process | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.process.serviceAccountName" -}}
{{- $in := .Values.process | default dict -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.process.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.process.serviceName" . -}}
{{- $port := include "groundx.process.containerPort" . -}}
{{- if eq $port "80" -}}
{{ printf "http://%s.%s.svc.cluster.local" $name $ns }}
{{- else -}}
{{ printf "http://%s.%s.svc.cluster.local:%v" $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.process.settings" -}}
{{- $in := .Values.process | default dict -}}
{{- $rep := (include "groundx.process.replicas" . | fromYaml) -}}
{{- $san := include "groundx.process.serviceAccountName" . -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "image"        (include "groundx.process.image" .)
  "name"         (include "groundx.process.serviceName" .)
  "node"         (include "groundx.process.node" .)
  "port"         (include "groundx.process.containerPort" .)
  "pull"         (include "groundx.process.imagePullPolicy" .)
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
