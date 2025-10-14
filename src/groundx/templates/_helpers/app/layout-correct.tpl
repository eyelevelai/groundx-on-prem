{{- define "groundx.layout.correct.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{- $df := include "groundx.node.cpuMemory" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.correct.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-correct" $svc }}
{{- end }}

{{- define "groundx.layout.correct.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.correct.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.correct.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
{{- end }}

{{- define "groundx.layout.correct.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{ dig "queue" "correct_queue" $in }}
{{- end }}

{{- define "groundx.layout.correct.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "correct" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.correct.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.correct.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.correct.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "correct" dict $b -}}
{{- $rep := (include "groundx.layout.api.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "celery"   ("document.celery_process")
  "image"    (include "groundx.layout.correct.image" .)
  "name"     (include "groundx.layout.correct.serviceName" .)
  "node"     (include "groundx.layout.correct.node" .)
  "pull"     (include "groundx.layout.correct.imagePullPolicy" .)
  "queue"    (include "groundx.layout.correct.queue" .)
  "replicas" ($rep)
  "service"  (include "groundx.layout.serviceName" .)
  "threads"  (include "groundx.layout.correct.threads" .)
  "workers"  (include "groundx.layout.correct.workers" .)
-}}
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
