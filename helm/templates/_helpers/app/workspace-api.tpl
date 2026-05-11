{{- define "groundx.workspace.api.values" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "api" dict $b | toYaml }}
{{- end }}

{{- define "groundx.workspace.api.node" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "api" dict $b -}}
{{ coalesce (dig "node" "" $in) (include "groundx.workspace.node" .) }}
{{- end }}

{{- define "groundx.workspace.api.serviceName" -}}
{{- $svc := include "groundx.workspace.serviceName" . -}}
{{ printf "%s-api" $svc }}
{{- end }}

{{- define "groundx.workspace.api.create" -}}
{{- if eq (include "groundx.workspace.create" .) "false" -}}
false
{{- else -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" true $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.workspace.api.containerPort" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.workspace.api.image" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/workspace-runner:%s" $repoPrefix $ver -}}
{{- coalesce (dig "image" "" $in) (dig "image" "" $b) $fallback -}}
{{- end }}

{{- define "groundx.workspace.api.imagePullPolicy" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{ coalesce (dig "imagePullPolicy" "" $in) (dig "imagePullPolicy" "" $b) (include "groundx.imagePullPolicy" .) }}
{{- end }}

{{- define "groundx.workspace.api.port" -}}
80
{{- end }}

{{- define "groundx.workspace.api.target.default" -}}
1
{{- end }}

{{- define "groundx.workspace.api.threshold.default" -}}
4000
{{- end }}

{{- define "groundx.workspace.api.throughput.default" -}}
50000
{{- end }}

{{- define "groundx.workspace.api.replicas" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{- $rep := dig "replicas" dict $in -}}
{{- $chp := include "groundx.cluster.hpa" . -}}
{{- if not $rep }}
  {{- $rep = dict -}}
{{- end }}
{{- if not (hasKey $rep "cooldown") -}}
  {{- $_ := set $rep "cooldown" (include "groundx.hpa.cooldown" .) -}}
{{- end -}}
{{- if not (hasKey $rep "hpa") -}}
  {{- $_ := set $rep "hpa" $chp -}}
{{- end -}}
{{- if not (hasKey $rep "target") -}}
  {{- $_ := set $rep "target" (include "groundx.workspace.api.target.default" .) -}}
{{- end -}}
{{- if not (hasKey $rep "threshold") -}}
  {{- $_ := set $rep "threshold" (include "groundx.workspace.api.threshold.default" .) -}}
{{- end -}}
{{- if not (hasKey $rep "throughput") -}}
  {{- $threads := (include "groundx.workspace.api.threads" . | int) -}}
  {{- $workers := (include "groundx.workspace.api.workers" . | int) -}}
  {{- $dflt := (include "groundx.workspace.api.throughput.default" . | int) -}}
  {{- $_ := set $rep "throughput" (mul $dflt $threads $workers) -}}
{{- end -}}
{{- if not (hasKey $rep "min") -}}
  {{- if hasKey $rep "desired" -}}
    {{- $_ := set $rep "min" (dig "desired" 1 $rep) -}}
  {{- else -}}
    {{- $_ := set $rep "min" 1 -}}
  {{- end -}}
{{- end -}}
{{- if not (hasKey $rep "desired") -}}
  {{- $_ := set $rep "desired" 1 -}}
{{- end -}}
{{- if not (hasKey $rep "max") -}}
  {{- $_ := set $rep "max" 16 -}}
{{- end -}}
{{- toYaml $rep | nindent 0 }}
{{- end }}

{{- define "groundx.workspace.api.hpa" -}}
{{- $ic := include "groundx.workspace.api.create" . -}}
{{- $rep := (include "groundx.workspace.api.replicas" . | fromYaml) -}}
{{- $enabled := false -}}
{{- if eq $ic "true" -}}{{- $enabled = dig "hpa" false $rep -}}{{- end -}}
{{- $name := include "groundx.workspace.api.serviceName" . -}}
{{- $cld := dig "cooldown" 60 $rep -}}
{{- dict
  "downCooldown" (mul $cld 2)
  "enabled" $enabled
  "metric" (printf "%s:api" $name)
  "name" $name
  "replicas" $rep
  "throughput" (printf "%s:throughput" $name)
  "upCooldown" $cld
  | toYaml -}}
{{- end }}

{{- define "groundx.workspace.api.threshold" -}}
{{- $rep := (include "groundx.workspace.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.workspace.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "threshold" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.workspace.api.throughput" -}}
{{- $rep := (include "groundx.workspace.api.replicas" . | fromYaml) -}}
{{- $ic := include "groundx.workspace.api.create" . -}}
{{- if eq $ic "true" -}}
{{ dig "throughput" 0 $rep }}
{{- else -}}
0
{{- end -}}
{{- end }}

{{- define "groundx.workspace.api.serviceAccountName" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{- $ex := dig "serviceAccount" dict $in -}}
{{ dig "name" (include "groundx.serviceAccountName" .) $ex }}
{{- end }}

{{- define "groundx.workspace.api.serviceType" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.workspace.api.serviceUrl" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.workspace.serviceName" . -}}
{{- $port := include "groundx.workspace.api.port" . -}}
{{- $ssl := include "groundx.workspace.api.ssl" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- if or (and (eq $sslStr "true") (eq $port "443")) (eq $port "80") -}}
{{ printf "%s://%s-api.%s.svc.cluster.local" $scheme $name $ns }}
{{- else -}}
{{ printf "%s://%s-api.%s.svc.cluster.local:%v" $scheme $name $ns $port }}
{{- end -}}
{{- end }}

{{- define "groundx.workspace.api.ssl" -}}
false
{{- end }}

{{- define "groundx.workspace.api.threads" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{ dig "threads" 2 $in }}
{{- end }}

{{- define "groundx.workspace.api.timeout" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{ dig "timeout" 120 $in }}
{{- end }}

{{- define "groundx.workspace.api.timeoutKeepAlive" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{ dig "timeoutKeepAlive" 15 $in }}
{{- end }}

{{- define "groundx.workspace.api.workers" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{ dig "workers" 2 $in }}
{{- end }}

{{- define "groundx.workspace.api.ingress" -}}
{{- $b := include "groundx.workspace.values" . | fromYaml -}}
{{- $in := dig "api" dict $b -}}
{{- $ing := dig "ingress" dict $in -}}
{{- $en := dig "enabled" "false" $ing | toString -}}
{{- if eq $en "true" -}}
{{- dict
      "data"    ($ing)
      "enabled" true
      "name"    (include "groundx.workspace.serviceName" .)
  | toYaml -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.workspace.api.interface" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{- dict
    "isInternal" (dig "isInternal" true $in)
    "port" (include "groundx.workspace.api.port" .)
    "ssl" "false"
    "targetPort" (include "groundx.workspace.api.containerPort" .)
    "timeout" ""
    "type" (include "groundx.workspace.api.serviceType" .)
  | toYaml -}}
{{- end }}

{{- define "groundx.workspace.api.settings" -}}
{{- $in := include "groundx.workspace.api.values" . | fromYaml -}}
{{- $rep := (include "groundx.workspace.api.replicas" . | fromYaml) -}}
{{- $san := include "groundx.workspace.api.serviceAccountName" . -}}
{{- $data := dict -}}
{{- if or (ne (include "groundx.workspace.existingSecret" .) "") (ne (include "groundx.workspace.token" .) "") -}}
{{- $_ := set $data (include "groundx.workspace.secretName" .) (include "groundx.workspace.secretName" .) -}}
{{- end -}}
{{- if ne (include "groundx.workspace.github.privateKeyPem" .) "" -}}
{{- $_ := set $data (include "groundx.workspace.githubSecretName" .) (include "groundx.workspace.githubSecretName" .) -}}
{{- end -}}
{{- if ne (include "groundx.workspace.gitlab.token" .) "" -}}
{{- $_ := set $data (include "groundx.workspace.gitlabSecretName" .) (include "groundx.workspace.gitlabSecretName" .) -}}
{{- end -}}
{{- $svc := include "groundx.workspace.serviceName" . -}}
{{- $apiSvc := include "groundx.workspace.api.serviceName" . -}}
{{- $cfg := dict
  "cfg" (printf "%s-config-py-map" $svc)
  "dependencies" (dict "cache" "cache" "db" "db")
  "gunicorn" (printf "%s-gunicorn-conf-py-map" $svc)
  "image" (include "groundx.workspace.api.image" .)
  "interface" (include "groundx.workspace.api.interface" .)
  "mapPrefix" $svc
  "name" $apiSvc
  "node" (include "groundx.workspace.api.node" .)
  "port" (include "groundx.workspace.api.containerPort" .)
  "pull" (include "groundx.workspace.api.imagePullPolicy" .)
  "pvc" (include "groundx.workspace.pvc" . | fromYaml)
  "replicas" $rep
  "volumeMounts" (include "groundx.workspace.volumeMounts" . | fromYamlArray)
  "volumes" (include "groundx.workspace.volumes" . | fromYamlArray)
-}}
{{- if gt (len $data) 0 }}{{- $_ := set $cfg "secrets" $data -}}{{- end -}}
{{- if hasKey $rep "gracePeriod" -}}
  {{- $_ := set $cfg "gracePeriod" (dig "gracePeriod" nil $rep) -}}
{{- end -}}
{{- if and $san (ne $san "") }}{{- $_ := set $cfg "serviceAccountName" $san -}}{{- end -}}
{{- range $k := list "affinity" "annotations" "containerSecurityContext" "labels" "nodeSelector" "resources" "securityContext" "tolerations" }}
{{- if and (hasKey $in $k) (not (empty (get $in $k))) }}{{- $_ := set $cfg $k (get $in $k) -}}{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}
