{{- define "groundx.extract.api.node" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.extract.api.serviceName" -}}
{{- $svc := include "groundx.extract.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.extract.api.create" -}}
{{- $is := include "groundx.extract.create" . -}}
{{- if eq $is "false" -}}
false
{{- else -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.extract.api.containerPort" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.extract.api.target.default" -}}
3
{{- end }}

{{/* average response time in seconds */}}
{{- define "groundx.extract.api.threshold.default" -}}
1
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.extract.api.throughput.default" -}}
30000
{{- end }}

{{- define "groundx.extract.api.threshold" -}}
{{- $rep := (include "groundx.extract.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.api.throughput" -}}
{{- $rep := (include "groundx.extract.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.extract.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.extract.api.hpa" -}}
{{- $ic := include "groundx.extract.api.create" . -}}
{{- $rep := (include "groundx.extract.api.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.extract.api.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:api" $name)
  "name"         $name
  "replicas"     $rep
  "throughput"   (include "groundx.extract.api.throughput" .)
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.extract.api.image" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/extract:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.extract.api.imagePullPolicy" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{- define "groundx.extract.api.port" -}}
80
{{- end }}

{{- define "groundx.extract.api.replicas" -}}
{{- $b := .Values.extract | default dict -}}
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
  {{- $_ := set $in "target" (include "groundx.extract.api.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.extract.api.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $threads := (include "groundx.extract.api.threads" . | int) -}}
  {{- $workers := (include "groundx.extract.api.workers" . | int) -}}
  {{- $dflt := (include "groundx.extract.api.throughput.default" . | int) -}}
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
  {{- $_ := set $in "max" 32 -}}
{{- end -}}
{{- toYaml $in | nindent 0 }}
{{- end }}

{{- define "groundx.extract.api.serviceAccountName" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.extract.api.serviceType" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.extract.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.extract.serviceName" . -}}
{{- $port := include "groundx.extract.api.port" . -}}
{{- $ssl := include "groundx.extract.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.extract.api.ssl" -}}
false
{{- end }}

{{- define "groundx.extract.api.threads" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.extract.api.timeout" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "timeout" 120 $in }}
{{- end }}

{{- define "groundx.extract.api.workers" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "workers" 2 $in }}
{{- end }}

{{- define "groundx.extract.api.ingress" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- $ing := dig "ingress" dict $in -}}
{{- $en := dig "enabled" "false" $ing | toString -}}
{{- if eq $en "true" -}}
{{- dict
      "data"    ($ing)
      "enabled" true
      "name"    (include "groundx.extract.serviceName" .)
  | toYaml -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.extract.api.interface" -}}
{{- $b := .Values.extract | default dict -}}
{{- $in := dig "api" dict $b -}}
{{- dict
    "isInternal" (dig "isInternal" true $in)
    "port"       (include "groundx.extract.api.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.extract.api.containerPort" .)
    "timeout"    ""
    "type"       (include "groundx.extract.api.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.extract.api.settings" -}}
{{- $svc := include "groundx.extract.serviceName" . -}}
{{- $b := .Values.extract | default dict -}}
{{- $ur := dig "callbackUrl" "" $b -}}
{{- $in := dig "api" dict $b -}}

{{- $dpnd := dict -}}

{{- $rep := (include "groundx.extract.api.replicas" . | fromYaml) -}}
{{- $san := include "groundx.extract.api.serviceAccountName" . -}}
{{- $data := dict
  (include "groundx.extract.save.secretName" .) (include "groundx.extract.save.secretName" .)
-}}
{{- $apiKey := include "groundx.extract.agent.apiKey" . -}}
{{- if ne $apiKey "" -}}
{{- $_ := set $data (include "groundx.extract.agent.secretName" .) (include "groundx.extract.agent.secretName" .) -}}
{{- end -}}
{{- $cfg := dict
  "cfg"          (printf "%s-config-py-map" $svc)
  "dependencies" $dpnd
  "fileDomain"   (include "groundx.extract.file.serviceDependency" .)
  "filePort"     (include "groundx.extract.file.port" .)
  "gunicorn"     (printf "%s-gunicorn-conf-py-map" $svc)
  "image"        (include "groundx.extract.api.image" .)
  "interface"    (include "groundx.extract.api.interface" .)
  "mapPrefix"    ("extract")
  "name"         (include "groundx.extract.api.serviceName" .)
  "node"         (include "groundx.extract.api.node" .)
  "port"         (include "groundx.extract.api.containerPort" .)
  "pull"         (include "groundx.extract.api.imagePullPolicy" .)
  "replicas"     ($rep)
  "secrets"      ($data)
-}}
{{- $dpnd := dict -}}
{{- if eq $ur "" -}}
  {{- $_ := set $dpnd "callback" (include "groundx.extract.callbackUrl" .) -}}
  {{- $_ := set $cfg "dependencies" $dpnd -}}
{{- end -}}
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
