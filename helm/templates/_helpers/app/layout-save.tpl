{{- define "groundx.layout.save.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $df := include "groundx.node.cpuMemory" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.save.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-save" $svc }}
{{- end }}

{{- define "groundx.layout.save.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.save.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.save.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
{{- end }}

{{- define "groundx.layout.save.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "queue" "save_queue,celery" $in }}
{{- end }}

{{- define "groundx.layout.save.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "save" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.save.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.save.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.save.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "save" dict $b -}}
{{- $rep := (include "groundx.layout.save.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "celery"   ("document.celery_process")
  "image"    (include "groundx.layout.save.image" .)
  "name"     (include "groundx.layout.save.serviceName" .)
  "node"     (include "groundx.layout.save.node" .)
  "pull"     (include "groundx.layout.save.imagePullPolicy" .)
  "queue"    (include "groundx.layout.save.queue" .)
  "replicas" ($rep)
  "service"  (include "groundx.layout.serviceName" .)
  "threads"  (include "groundx.layout.save.threads" .)
  "workers"  (include "groundx.layout.save.workers" .)
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
