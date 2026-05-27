{{- define "groundx.ranker.api.node" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.ranker.api.serviceName" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.ranker.api.create" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $io := include "groundx.ingestOnly" . -}}
{{- if eq $io "true" -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.containerPort" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.ranker.api.image" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/python-api:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.ranker.api.imagePullPolicy" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.ranker.api.port" -}}
80
{{- end }}

{{- define "groundx.ranker.api.serviceAccountName" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.ranker.api.serviceType" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.ranker.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.ranker.serviceName" . -}}
{{- $port := include "groundx.ranker.api.port" . -}}
{{- $ssl := include "groundx.ranker.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.ranker.api.target.default" -}}
1
{{- end }}

{{/* average latency per minute */}}
{{- define "groundx.ranker.api.threshold.default" -}}
4000
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.ranker.api.throughput.default" -}}
90000
{{- end }}

{{- define "groundx.ranker.api.threshold" -}}
{{- $rep := (include "groundx.ranker.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.ranker.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.throughput" -}}
{{- $rep := (include "groundx.ranker.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.ranker.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.hpa" -}}
{{- $ic := include "groundx.ranker.api.create" . -}}
{{- $rep := (include "groundx.ranker.api.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.ranker.api.serviceName" .) -}}
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

{{- define "groundx.ranker.api.replicas" -}}
{{- $b := .Values.ranker | default dict -}}
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
  {{- $_ := set $in "target" (include "groundx.ranker.api.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.ranker.api.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.ranker.api.threads" . | int) -}}
  {{- $workers := (include "groundx.ranker.api.workers" . | int) -}}
  {{- $dflt := (include "groundx.ranker.api.throughput.default" . | int) -}}
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

{{- define "groundx.ranker.api.ssl" -}}
false
{{- end }}

{{- define "groundx.ranker.api.threads" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "threads" 3 $in }}
{{- end }}

{{- define "groundx.ranker.api.timeout" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "timeout" 120 $in }}
{{- end }}

{{- define "groundx.ranker.api.workers" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "workers" 1 $in }}
{{- end }}

{{- define "groundx.ranker.api.ingress" -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ing := dig "ingress" dict $in -}}
{{- $en := dig "enabled" "false" $ing | toString -}}
{{- if eq $en "true" -}}
{{- dict
      "data"    ($ing)
      "enabled" true
      "name"    (include "groundx.ranker.serviceName" .)
  | toYaml -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.ranker.api.interface" -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.ranker.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.ranker.api.containerPort" .)
    "timeout"    ""
    "type"       (include "groundx.ranker.api.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.ranker.api.settings" -}}
{{- $svc := include "groundx.ranker.serviceName" . -}}
{{- $b := .Values.ranker | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $rep := (include "groundx.ranker.api.replicas" . | fromYaml) -}}
{{- $san := include "groundx.ranker.api.serviceAccountName" . -}}
{{- $cfg := dict
  "cfg"          (printf "%s-config-py-map" $svc)
  "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc)
  "image"        (include "groundx.ranker.api.image" .)
  "interface"    (include "groundx.ranker.api.interface" .)
  "mapPrefix"    ("ranker")
  "name"         (include "groundx.ranker.api.serviceName" .)
  "node"         (include "groundx.ranker.api.node" .)
  "port"         (include "groundx.ranker.api.containerPort" .)
  "pull"         (include "groundx.ranker.api.imagePullPolicy" .)
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
