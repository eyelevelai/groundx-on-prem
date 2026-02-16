{{- define "groundx.summary.api.node" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.summary.api.serviceName" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.summary.api.create" -}}
{{- $is := include "groundx.summary.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.containerPort" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summary.api.image" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/python-api:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.summary.api.imagePullPolicy" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ (dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in) }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.summary.api.target.default" -}}
0.8
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.summary.api.threshold.default" -}}
2400
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.summary.api.throughput.default" -}}
2400
{{- end }}

{{- define "groundx.summary.api.threshold" -}}
{{- $rep := (include "groundx.summary.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.summary.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.throughput" -}}
{{- $rep := (include "groundx.summary.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.summary.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.hpa" -}}
{{- $ic := include "groundx.summary.api.create" . -}}
{{- $rep := (include "groundx.summary.api.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.summary.api.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:inference" $name)
  "name"         $name
  "replicas"     $rep
  "throughput"   (include "groundx.summary.api.throughput" .)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.summary.api.port" -}}
80
{{- end }}

{{- define "groundx.summary.api.replicas" -}}
{{- $b := .Values.summary | default dict -}}
{{- $c := dig "api" dict $b -}}
{{- $in := dig "replicas" dict $c -}}
{{- $chp := include "groundx.cluster.hpa" . -}}
{{- if not $in }}
  {{- $in = dict -}}
{{- end }}
{{- if not (hasKey $in "cooldown") -}}
  {{- $_ := set $in "cooldown" (include "groundx.hpa.cooldown" .) -}}
{{- end -}}
{{- if not (hasKey $in "hpa") -}}
  {{- $_ := set $in "hpa" $chp -}}
{{- end -}}
{{- if not (hasKey $in "target") -}}
  {{- $_ := set $in "target" (include "groundx.summary.api.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.summary.api.threads" . | int) -}}
  {{- $workers := (include "groundx.summary.api.workers" . | int) -}}
  {{- $dflt := (include "groundx.summary.api.throughput.default" . | int) -}}
  {{- $_ := set $in "throughput" (mul $dflt $threads $workers) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (dig "throughput" 0 $in) -}}
{{- end -}}
{{- if not (hasKey $in "min") -}}
  {{- if hasKey $in "desired" -}}
    {{- $_ := set $in "min" (dig "desired" 1 $in) -}}
  {{- else -}}
    {{- $_ := set $in "min" 1 -}}
  {{- end -}}
{{- end -}}
{{- if not (hasKey $in "desired") -}}
  {{- $_ := set $in "desired" 1 -}}
{{- end -}}
{{- if not (hasKey $in "max") -}}
  {{- $_ := set $in "max" 32 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.summary.api.serviceAccountName" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.summary.api.serviceType" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.summary.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.summary.serviceName" . -}}
{{- $port := include "groundx.summary.api.port" . -}}
{{- $ssl := include "groundx.summary.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.ssl" -}}
false
{{- end }}

{{- define "groundx.summary.api.threads" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "threads" 4 $in }}
{{- end }}

{{- define "groundx.summary.api.timeout" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "timeout" 240 $in }}
{{- end }}

{{- define "groundx.summary.api.workers" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.summary.api.ingress" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ing := dig "ingress" dict $in -}}
{{- $en := dig "enabled" "false" $ing | toString -}}
{{- if eq $en "true" -}}
{{- dict
      "data"    ($ing)
      "enabled" true
      "name"    (include "groundx.summary.serviceName" .)
  | toYaml -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.summary.api.interface" -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- dict
    "isInternal" (dig "isInternal" true $in)
    "port"       (include "groundx.summary.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.summary.api.containerPort" .)
    "timeout"    ""
    "type"       (include "groundx.summary.api.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.summary.api.settings" -}}
{{- $svc := include "groundx.summary.serviceName" . -}}
{{- $b := .Values.summary | default dict -}}
{{- $in := dig "api" dict $b -}}

{{- $dpnd := dict -}}

{{- $rep := (include "groundx.summary.api.replicas" . | fromYaml) -}}
{{- $san := include "groundx.summary.api.serviceAccountName" . -}}
{{- $cfg := dict
  "cfg"          (printf "%s-config-py-map" $svc)
  "dependencies" $dpnd
  "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc)
  "image"        (include "groundx.summary.api.image" .)
  "interface"    (include "groundx.summary.api.interface" .)
  "mapPrefix"    ("summary")
  "name"         (include "groundx.summary.api.serviceName" .)
  "node"         (include "groundx.summary.api.node" .)
  "port"         (include "groundx.summary.api.containerPort" .)
  "pull"         (include "groundx.summary.api.imagePullPolicy" .)
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
