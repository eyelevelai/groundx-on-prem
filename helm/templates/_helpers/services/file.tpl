{{- define "groundx.file.serviceName" -}}
{{- $in := .Values.file | default dict -}}
{{ dig "serviceName" "minio" $in }}
{{- end }}

{{- define "groundx.file.existing" -}}
{{- $in := .Values.file | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{ not (empty (dig "url" "" $ex)) }}
{{- end }}

{{- define "groundx.file.create" -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.file.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.file.serviceName" . -}}
{{- printf "%s.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.file.bucketDomain" -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ include "groundx.file.domain" . }}
{{- else -}}
{{ include "groundx.file.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.file.bucketName" -}}
{{- $in := .Values.file | default dict -}}
{{ dig "bucketName" "eyelevel" $in }}
{{- end }}

{{- define "groundx.file.bucketSsl" -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ include "groundx.file.ssl" . }}
{{- else -}}
{{- $in := .Values.file | default dict -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- if hasKey $lb "ssl" }}
{{ $lb.ssl }}
{{- else -}}
{{ dig "ssl" "false" $in }}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.file.domain" -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $ex := dig "existing" dict $in -}}
{{- $url := dig "url" "" $ex -}}
{{- $parts := splitList "://" $url -}}
{{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
{{ index $parts 1 }}
{{- else -}}
{{ include "groundx.file.serviceHost" . }}
{{- end -}}
{{- else if and (hasKey $in "customDomain") (not (empty $in.customDomain)) }}
{{ $in.customDomain }}
{{- else -}}
{{ include "groundx.file.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.file.password" -}}
{{- $in := .Values.file | default dict -}}
{{ dig "password" "" $in }}
{{- end }}

{{- define "groundx.file.port" -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $ex := dig "existing" dict $in -}}
{{- $url := dig "url" "" $ex -}}
{{- $parts := splitList "://" $url -}}
{{- $domain := $url -}}
{{- $sch := "http" -}}
{{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
{{- $sch = index $parts 0 -}}
{{- $domain = index $parts 1 -}}
{{- end -}}
{{- $pparts := splitList ":" $domain -}}
{{- $rawPort := dig "port" "" $ex -}}
{{- $port := -1 -}}
{{- if (kindIs "string" $rawPort) }}
{{- $port = (int $rawPort) -}}
{{- else if (kindIs "int" $rawPort) }}
  {{- $port = $rawPort -}}
{{- end -}}
{{- if gt $port 0 -}}
{{ $port }}
{{- else if and (kindIs "slice" $pparts) (eq (len $pparts) 2) -}}
{{ index $pparts 1 }}
{{- else if eq $sch "https" -}}
443
{{- else -}}
80
{{- end -}}
{{- else -}}
{{ dig "port" 9000 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.file.region" -}}
{{- $in := .Values.file | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{ dig "region" "" $ex }}
{{- end }}

{{- define "groundx.file.serviceDependency" -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $domain := include "groundx.file.domain" . -}}
{{- $parts := splitList ":" $domain -}}
{{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
{{ index $parts 0 }}
{{- else -}}
{{ $domain }}
{{- end -}}
{{- else -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.file.serviceName" . -}}
{{- printf "%s-tenant-hl.%s.svc.cluster.local" $name $ns -}}
{{- end -}}
{{- end }}

{{- define "groundx.file.serviceType" -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $ex := dig "existing" dict $in -}}
{{ dig "serviceType" (dig "serviceType" "minio" $in) $ex }}
{{- else -}}
{{ dig "serviceType" "minio" $in }}
{{- end -}}
{{- end }}

{{- define "groundx.file.ssl" -}}
{{- $in := .Values.file | default dict -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $ex := dig "existing" dict $in -}}
{{- $url := dig "url" "" $ex -}}
{{- $parts := splitList "://" $url -}}
{{- $sch := "http" -}}
{{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
{{- $sch = index $parts 0 -}}
{{- end -}}
{{- if eq $sch "https" -}}
true
{{- else -}}
false
{{- end -}}
{{- else if hasKey $lb "ssl" -}}
{{ dig "ssl" "" $lb }}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.file.token" -}}
{{- $in := .Values.file | default dict -}}
{{ dig "token" "" $in }}
{{- end }}

{{- define "groundx.file.username" -}}
{{- $in := .Values.file | default dict -}}
{{ dig "username" "" $in }}
{{- end }}

{{- define "groundx.file.loadBalancer" -}}
{{- $in := .Values.file | default dict -}}
{{- $lb := dig "loadBalancer" dict $in -}}
{{- $name := dig "name" "" $lb -}}
{{- if hasKey $lb "port" }}
{{- $lbDict := dict
    "isInternal" (dig "isInternal" "false" $lb)
    "port"       (dig "port" "" $lb)
    "ssl"        (dig "ssl" "" $lb)
    "targetPort" (include "groundx.file.port" .)
    "timeout"    (dig "timeout" "" $lb)
-}}
{{- if ne $name "" -}}
  {{- $_ := set $lbDict "name" $name -}}
{{- end -}}
{{- $lbDict | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.file.settings" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $svc := include "groundx.file.serviceName" . -}}
{{- $ssl := include "groundx.file.ssl" . -}}
{{- $token := include "groundx.file.token" . -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- $bucketSSL := include "groundx.file.bucketSsl" . -}}
{{- $bucketSSLStr := printf "%v" $bucketSSL -}}
{{- $bucketScheme := "http" -}}
{{- if eq $bucketSSLStr "true" -}}{{- $bucketScheme = "https" -}}{{- end -}}
{{- dict
    "baseDomain"   (include "groundx.file.domain" .)
    "bucketName"   (include "groundx.file.bucketName" .)
    "bucketDomain" (include "groundx.file.bucketDomain" .)
    "bucketScheme" $bucketScheme
    "bucketSSL"    $bucketSSL
    "dependency"   (include "groundx.file.serviceDependency" .)
    "serviceType"  (include "groundx.file.serviceType" .)
    "username"     (include "groundx.file.username" .)
    "password"     (include "groundx.file.password" .)
    "port"         (include "groundx.file.port" .)
    "region"       (include "groundx.file.region" .)
    "scheme"       $scheme
    "ssl"          $ssl
    "token"        $token
  | toYaml -}}
{{- end }}
