{{- define "groundx.groundx.node" -}}
{{- $in := .Values.groundx | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.groundx.serviceName" -}}
{{- $in := .Values.groundx | default dict -}}
{{ dig "serviceName" "groundx" $in }}
{{- end }}

{{- define "groundx.groundx.create" -}}
{{- $in := .Values.groundx | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.groundx.containerPort" -}}
{{- $in := .Values.groundx | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.groundx.image" -}}
{{- $in := .Values.groundx | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/groundx:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.groundx.imagePullPolicy" -}}
{{- $in := .Values.groundx | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.groundx.target.default" -}}
3
{{- end }}

{{/* queue message backlog */}}
{{- define "groundx.groundx.threshold.default" -}}
1
{{- end }}

{{/* tokens per minute per worker per thread */}}
{{- define "groundx.groundx.throughput.default" -}}
30000
{{- end }}

{{- define "groundx.groundx.threshold" -}}
{{- $rep := (include "groundx.groundx.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.groundx.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.groundx.throughput" -}}
{{- $rep := (include "groundx.groundx.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.groundx.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.groundx.hpa" -}}
{{- $ic := include "groundx.groundx.create" . -}}
{{- $rep := (include "groundx.groundx.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.groundx.serviceName" .) -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- $cfg := dict
  "downCooldown" (mul $cld 2)
  "enabled"      $enabled
  "metric"       (printf "%s:api" $name)
  "name"         $name
  "replicas"     $rep
  "upCooldown"   $cld
-}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.groundx.port" -}}
80
{{- end }}

{{- define "groundx.groundx.replicas" -}}
{{- $b := .Values.groundx | default dict -}}
{{- $in := dig "replicas" dict $b -}}
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
  {{- $_ := set $in "target" (include "groundx.groundx.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.groundx.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $_ := set $in "throughput" (include "groundx.groundx.throughput.default" .) -}}
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

{{- define "groundx.groundx.serviceAccountName" -}}
{{- $in := .Values.groundx | default dict -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.groundx.serviceType" -}}
{{- $in := .Values.groundx | default dict -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.groundx.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.groundx.serviceName" . -}}
{{- $port := include "groundx.groundx.port" . -}}
{{- $ssl := include "groundx.groundx.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.groundx.ssl" -}}
false
{{- end }}

{{- define "groundx.groundx.type" -}}
{{- $in := .Values.groundx | default dict -}}
{{ (dig "type" "all" $in) }}
{{- end }}

{{- define "groundx.groundx.ingress" -}}
{{- $in := .Values.groundx | default dict -}}
{{- $ing := dig "ingress" dict $in -}}
{{- $en := dig "enabled" true $ing -}}
{{- if eq $en true -}}
{{- dict
      "data"    ($ing)
      "enabled" true
      "name"    (include "groundx.groundx.serviceName" .)
  | toYaml -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.groundx.interface" -}}
{{- $in := .Values.groundx | default dict -}}
{{- dict
    "isInternal" (dig "isInternal" true $in)
    "port"       (include "groundx.groundx.port" .)
    "ssl"        (include "groundx.groundx.ssl" .)
    "targetPort" (include "groundx.groundx.containerPort" .)
    "timeout"    ""
    "type"       (include "groundx.groundx.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.groundx.settings" -}}
{{- $in := .Values.groundx | default dict -}}

{{- $dpnd := dict
  "cache"  "cache"
  "file"   "file"
  "db"     "db"
-}}

{{- $cs := include "groundx.search.create" . -}}
{{- $es := include "groundx.search.existing" . -}}
{{- if or (eq $cs "true") (eq $es "true") -}}
{{- $_ := set $dpnd "search" "search" -}}
{{- end -}}

{{- $cd := include "groundx.stream.create" . -}}
{{- $ed := include "groundx.stream.existing" . -}}
{{- if or (eq $cd "true") (eq $ed "true") -}}
{{- $_ := set $dpnd "stream" "stream" -}}
{{- end -}}

{{- $rep := (include "groundx.groundx.replicas" . | fromYaml) -}}
{{- $san := include "groundx.groundx.serviceAccountName" . -}}

{{- $cfg := dict
  "dependencies" $dpnd
  "image"        (include "groundx.groundx.image" .)
  "interface"    (include "groundx.groundx.interface" . | trim)
  "name"         (include "groundx.groundx.serviceName" .)
  "node"         (include "groundx.groundx.node" .)
  "port"         (include "groundx.groundx.containerPort" .)
  "pull"         (include "groundx.groundx.imagePullPolicy" .)
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
