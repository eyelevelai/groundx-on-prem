{{- define "groundx.layout.api.node" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layout.api.serviceName" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.layout.api.create" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.containerPort" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layout.api.image" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/python-api:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layout.api.imagePullPolicy" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.layout.api.target.default" -}}
1
{{- end }}

{{/* average latency per minute */}}
{{- define "groundx.layout.api.threshold.default" -}}
4000
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.layout.api.throughput.default" -}}
90000
{{- end }}

{{- define "groundx.layout.api.threshold" -}}
{{- $rep := (include "groundx.layout.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.throughput" -}}
{{- $rep := (include "groundx.layout.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layout.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.hpa" -}}
{{- $ic := include "groundx.layout.api.create" . -}}
{{- $rep := (include "groundx.layout.api.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.layout.api.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:api" $name)
  "name"         $name
  "replicas"     $rep
  "throughput"   (printf "%s:throughput" $name)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.layout.api.port" -}}
80
{{- end }}

{{- define "groundx.layout.api.replicas" -}}
{{- $b := .Values.layout | default dict -}}
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
  {{- $_ := set $in "target" (include "groundx.layout.api.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.layout.api.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.layout.api.threads" . | int) -}}
  {{- $workers := (include "groundx.layout.api.workers" . | int) -}}
  {{- $dflt := (include "groundx.layout.api.throughput.default" . | int) -}}
  {{- $_ := set $in "throughput" (mul $dflt $threads $workers) -}}
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
  {{- $_ := set $in "max" 16 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.layout.api.serviceAccountName" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.layout.api.serviceType" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.layout.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.layout.serviceName" . -}}
{{- $port := include "groundx.layout.api.port" . -}}
{{- $ssl := include "groundx.layout.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.ssl" -}}
false
{{- end }}

{{- define "groundx.layout.api.threads" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "threads" 1 $in }}
{{- end }}

{{- define "groundx.layout.api.timeout" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "timeout" 120 $in }}
{{- end }}

{{- define "groundx.layout.api.workers" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "workers" 2 $in }}
{{- end }}

{{- define "groundx.layout.api.ingress" -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ing := dig "ingress" dict $in -}}
{{- $en := dig "enabled" "false" $ing | toString -}}
{{- if eq $en "true" -}}
{{- dict
      "data"    ($ing)
      "enabled" true
      "name"    (include "groundx.layout.serviceName" .)
  | toYaml -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.layout.api.interface" -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.layout.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.layout.api.containerPort" .)
    "timeout"    ""
    "type"       (include "groundx.layout.api.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.layout.api.settings" -}}
{{- $svc := include "groundx.layout.serviceName" . -}}
{{- $b := .Values.layout | default dict -}}
{{- $in := dig "api" dict $b -}}

{{- $dpnd := dict -}}

{{- $rep := (include "groundx.layout.api.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layout.api.serviceAccountName" . -}}
{{- $cfg := dict
  "cfg"          (printf "%s-config-py-map" $svc)
  "dependencies" $dpnd
  "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc)
  "image"        (include "groundx.layout.api.image" .)
  "interface"    (include "groundx.layout.api.interface" .)
  "mapPrefix"    ("layout")
  "name"         (include "groundx.layout.api.serviceName" .)
  "node"         (include "groundx.layout.api.node" .)
  "port"         (include "groundx.layout.api.containerPort" .)
  "pull"         (include "groundx.layout.api.imagePullPolicy" .)
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
