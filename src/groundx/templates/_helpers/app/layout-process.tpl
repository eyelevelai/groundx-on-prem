{{- define "groundx.layout.process.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- $df := include "groundx.node.cpuMemory" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.process.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-process" $svc }}
{{- end }}

{{- define "groundx.layout.process.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.process.batchSize" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "batchSize" 40 $in }}
{{- end }}

{{- define "groundx.layout.process.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $fallback := printf "%s/eyelevel/layout-process:latest" $repoPrefix -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.process.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "imagePullPolicy" "Always" $in }}
{{- end }}

{{- define "groundx.layout.process.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "queue" "process_queue" $in }}
{{- end }}

{{- define "groundx.layout.process.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "process" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.process.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.process.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.process.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "process" dict $b -}}
{{- $rep := (include "groundx.layout.process.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "node"     (include "groundx.layout.process.node" .)
  "replicas" ($rep)
-}}
{{- $_ := set $cfg "name"         (include "groundx.layout.process.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.process.image" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.process.imagePullPolicy" .) -}}
{{- $_ := set $cfg "queue"        (include "groundx.layout.process.queue" .) -}}
{{- $_ := set $cfg "threads"      (include "groundx.layout.process.threads" .) -}}
{{- $_ := set $cfg "workers"      (include "groundx.layout.process.workers" .) -}}
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
