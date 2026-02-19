{{- define "groundx.layoutWebhook.node" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.layoutWebhook.serviceName" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "serviceName" "layout-webhook" $in }}
{{- end }}

{{- define "groundx.layoutWebhook.create" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.containerPort" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.layoutWebhook.image" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/layout-webhook:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.layoutWebhook.imagePullPolicy" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in }}
{{- end }}

{{/* fraction of threshold */}}
{{- define "groundx.layoutWebhook.target.default" -}}
1
{{- end }}

{{/* average latency per minute */}}
{{- define "groundx.layoutWebhook.threshold.default" -}}
4000
{{- end }}

{{/* tokens per minute */}}
{{- define "groundx.layoutWebhook.throughput.default" -}}
150000
{{- end }}

{{- define "groundx.layoutWebhook.threshold" -}}
{{- $rep := (include "groundx.layoutWebhook.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layoutWebhook.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.throughput" -}}
{{- $rep := (include "groundx.layoutWebhook.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.layoutWebhook.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.hpa" -}}
{{- $ic := include "groundx.layoutWebhook.create" . -}}
{{- $rep := (include "groundx.layoutWebhook.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}
{{- $enabled = dig "hpa" false $rep -}}
{{- end -}}
{{- $name := (include "groundx.layoutWebhook.serviceName" .) -}}
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

{{- define "groundx.layoutWebhook.port" -}}
80
{{- end }}

{{- define "groundx.layoutWebhook.replicas" -}}
{{- $b := .Values.layoutWebhook | default dict -}}
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
  {{- $_ := set $in "target" (include "groundx.layoutWebhook.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "threshold") -}}
  {{- $_ := set $in "threshold" (include "groundx.layoutWebhook.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $in "throughput") -}}
  {{- $_ := set $in "throughput" (include "groundx.layoutWebhook.throughput.default" .) -}}
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

{{- define "groundx.layoutWebhook.serviceAccountName" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.layoutWebhook.serviceType" -}}
{{- $b := .Values.layoutWebhook | default dict -}}
{{- $in := dig "api" dict $b -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.layoutWebhook.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.layoutWebhook.serviceName" . -}}
{{- $port := include "groundx.layoutWebhook.port" . -}}
{{- $ssl := include "groundx.layoutWebhook.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.ssl" -}}
false
{{- end }}

{{- define "groundx.layoutWebhook.ingress" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $ing := dig "ingress" dict $in -}}
{{- $en := dig "enabled" "false" $ing | toString -}}
{{- if eq $en "true" -}}
{{- dict
      "data"    ($ing)
      "enabled" true
      "name"    (include "groundx.layoutWebhook.serviceName" .)
  | toYaml -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.layoutWebhook.interface" -}}
{{- dict
    "isInternal" "true"
    "port"       (include "groundx.layoutWebhook.port" .)
    "ssl"        "false"
    "targetPort" (include "groundx.layoutWebhook.containerPort" .)
    "timeout"    ""
    "type"       (include "groundx.layoutWebhook.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.layoutWebhook.settings" -}}
{{- $in := .Values.layoutWebhook | default dict -}}
{{- $rep := (include "groundx.layoutWebhook.replicas" . | fromYaml) -}}
{{- $san := include "groundx.layoutWebhook.serviceAccountName" . -}}
{{- $cfg := dict
  "dependencies" (dict
    "groundx" "groundx"
  )
  "image"        (include "groundx.layoutWebhook.image" .)
  "interface"    (include "groundx.layoutWebhook.interface" . | trim)
  "name"         (include "groundx.layoutWebhook.serviceName" .)
  "node"         (include "groundx.layoutWebhook.node" .)
  "port"         (include "groundx.layoutWebhook.containerPort" .)
  "pull"         (include "groundx.layoutWebhook.imagePullPolicy" .)
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
