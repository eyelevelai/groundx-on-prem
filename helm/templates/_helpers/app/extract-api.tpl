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
{{- if not $in }}
  {{- $in = dict "desired" 1 "max" 1 "min" 1 -}}
{{- end }}
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
{{- dict
    "isInternal" "true"
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
{{- $in := dig "api" dict $b -}}
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
  "dependencies" (dict
    "callback" (include "groundx.extract.callbackUrl" .)
  )
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
