{{- define "groundx.layout.inference.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $df := include "groundx.node.gpuLayout" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.inference.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-inference" $svc }}
{{- end }}

{{- define "groundx.layout.inference.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.inference.containerPort" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layout.inference.deviceType" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "deviceType" "cuda" $in) }}
{{- end }}

{{- define "groundx.layout.inference.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-inference:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.inference.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.layout.inference.queue" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ (dig "queue" "layout_queue" $in) }}
{{- end }}

{{- define "groundx.layout.inference.replicas" -}}
{{- $b := .Values.layout | default dict -}}
{{- $c := dig "inference" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.inference.serviceAccountName" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.layout.inference.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "threads" 6 $in }}
{{- end }}

{{- define "groundx.layout.inference.updateStrategy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "updateStrategy" "" $in }}
{{- end }}

{{- define "groundx.layout.inference.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.layout.inference.settings" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "inference" dict $b -}}
{{- $rep := (include "groundx.layout.inference.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layout.inference.serviceAccountName" . -}}
{{- $cfg := dict
  "baseName"       ($svc)
  "cfg"            (printf "%s-config-py-map" $svc)
  "execOpts"       ("python /app/init-layout.py &&")
  "fileSync"       ("true")
  "image"          (include "groundx.layout.inference.image" .)
  "mapPrefix"      ("layout")
  "name"           (include "groundx.layout.inference.serviceName" .)
  "node"           (include "groundx.layout.inference.node" .)
  "port"           (include "groundx.layout.inference.containerPort" .)
  "pull"           (include "groundx.layout.inference.imagePullPolicy" .)
  "queue"          (include "groundx.layout.inference.queue" .)
  "replicas"       ($rep)
  "supervisord"    (printf "%s-inference-supervisord-conf-map" $svc)
  "threads"        (include "groundx.layout.inference.threads" .)
  "updateStrategy" (include "groundx.layout.inference.updateStrategy" .)
  "workers"        (include "groundx.layout.inference.workers" .)
  "workingDir"     ("/app")
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
