{{- define "groundx.layout.map.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.map.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-map" $svc }}
{{- end }}

{{- define "groundx.layout.map.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.map.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-process:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.map.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
{{- end }}

{{- define "groundx.layout.map.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "queue" "map_queue" $in }}
{{- end }}

{{- define "groundx.layout.map.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "map" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.map.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.map.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.map.settings" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "map" dict $b -}}
{{- $rep := (include "groundx.layout.map.replicas" . | fromYaml) -}}
{{- $cfg := dict
  "celery"   ("document.celery_process")
  "image"    (include "groundx.layout.map.image" .)
  "name"     (include "groundx.layout.map.serviceName" .)
  "node"     (include "groundx.layout.map.node" .)
  "pull"     (include "groundx.layout.map.imagePullPolicy" .)
  "queue"    (include "groundx.layout.map.queue" .)
  "replicas" ($rep)
  "service"  (include "groundx.layout.serviceName" .)
  "threads"  (include "groundx.layout.map.threads" .)
  "workers"  (include "groundx.layout.map.workers" .)
-}}
{{- $_ := set $cfg "name"         (include "groundx.layout.map.serviceName" .) -}}
{{- $_ := set $cfg "image"        (include "groundx.layout.map.image" .) -}}
{{- $_ := set $cfg "pull"         (include "groundx.layout.map.imagePullPolicy" .) -}}
{{- $_ := set $cfg "queue"        (include "groundx.layout.map.queue" .) -}}
{{- $_ := set $cfg "threads"      (include "groundx.layout.map.threads" .) -}}
{{- $_ := set $cfg "workers"      (include "groundx.layout.map.workers" .) -}}
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
