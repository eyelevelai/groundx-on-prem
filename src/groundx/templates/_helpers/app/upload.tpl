{{- define "groundx.upload.node" -}}
{{- $in := .Values.upload | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.upload.serviceName" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "serviceName" "upload" $in }}
{{- end }}

{{- define "groundx.upload.create" -}}
{{- $in := .Values.upload | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.upload.containerPort" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.upload.image" -}}
{{- $b := .Values.upload | default dict -}}
{{- $in := dig "image" dict $b -}}
{{- $bs := printf "%s/eyelevel/upload" (include "groundx.imageRepository" .) -}}
{{ printf "%s:%s" (dig "repository" $bs $in) (dig "repository" "latest" $in) }}
{{- end }}

{{- define "groundx.upload.pull" -}}
{{- $b := .Values.upload | default dict -}}
{{- $in := dig "image" dict $b -}}
{{ (dig "pull" "Always" $in) }}
{{- end }}

{{- define "groundx.upload.queueSize" -}}
{{- $in := .Values.upload | default dict -}}
{{ dig "queueSize" 4 $in }}
{{- end }}

{{- define "groundx.upload.replicas" -}}
{{- $b := .Values.upload | default dict -}}
{{- $in := dig "replicas" dict $b -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.upload.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.upload.serviceName" . -}}
{{- $port := include "groundx.upload.containerPort" . -}}
{{- if eq $port "80" -}}
{{ printf "http://%s.%s.svc.cluster.local" $name $ns }}
{{- else -}}
{{ printf "http://%s.%s.svc.cluster.local:%v" $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.upload.settings" -}}
{{- $in := .Values.upload | default dict -}}
{{- $rep := (include "groundx.upload.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "node"         (include "groundx.upload.node" .)
  "replicas"     ($rep)
-}}
{{- $_ := set $cfg "name"         (include "groundx.upload.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.upload.image" .) -}}
{{- $_ := set $cfg "port"         (include "groundx.upload.containerPort" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.upload.pull" .) -}}
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
