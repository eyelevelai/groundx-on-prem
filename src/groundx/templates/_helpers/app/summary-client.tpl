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
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
{{- end }}

{{- define "groundx.summaryClient.queueSize" -}}
{{- $in := .Values.summaryClient | default dict -}}
{{ dig "queueSize" 3 $in }}
{{- end }}

{{- define "groundx.summaryClient.replicas" -}}
{{- $b := .Values.summaryClient | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
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
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "node"         (include "groundx.summaryClient.node" .)
  "replicas"     ($rep)
-}}
{{- $_ := set $cfg "name"         (include "groundx.summaryClient.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.summaryClient.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.summaryClient.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.summaryClient.imagePullPolicy" .) -}}
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
