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
false
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
{{- $in.customDomain -}}
{{- else -}}
{{ include "groundx.file.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.file.password" -}}
{{- $in := .Values.file | default dict -}}
{{ dig "password" "" $in }}
{{- end }}

{{- define "groundx.file.url.settings" -}}
{{- $url := dig "url" "" . -}}
{{- $parts := splitList "://" $url -}}
{{- $domain := $url -}}
{{- $scheme := "http" -}}
{{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
{{- $scheme = index $parts 0 -}}
{{- $domain = index $parts 1 -}}
{{- end -}}
{{- $pparts := splitList ":" $domain -}}
{{- $dependency := $domain -}}
{{- if eq (len $pparts) 2 -}}{{- $dependency = index $pparts 0 -}}{{- end -}}
{{- $rawPort := dig "port" "" . -}}
{{- $port := -1 -}}
{{- if kindIs "string" $rawPort -}}
  {{- $port = int $rawPort -}}
{{- else if kindIs "int" $rawPort -}}
  {{- $port = $rawPort -}}
{{- end -}}
{{- $connectionPort := $port | toString -}}
{{- if le $port 0 -}}
  {{- if eq (len $pparts) 2 -}}
    {{- $connectionPort = index $pparts 1 -}}
  {{- else -}}
    {{- $connectionPort = ternary "443" "80" (eq $scheme "https") -}}
  {{- end -}}
{{- end -}}
{{- dict
    "baseDomain" $domain
    "bucketDomain" $domain
    "bucketSSL" (eq $scheme "https")
    "scheme" $scheme
    "ssl" (eq $scheme "https")
    "dependency" $dependency
    "port" $connectionPort
  | toYaml -}}
{{- end }}

{{- define "groundx.file.port" -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- get (include "groundx.file.url.settings" (dig "existing" dict $in) | fromYaml) "port" -}}
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
{{ dig "serviceType" "ClusterIP" $in }}
{{- end }}

{{- define "groundx.file.storageType" -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- $ex := dig "existing" dict $in -}}
{{ dig "serviceType" (dig "serviceType" "minio" $in) $ex }}
{{- else -}}
minio
{{- end -}}
{{- end }}

{{- define "groundx.file.ssl" -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{- get (include "groundx.file.url.settings" (dig "existing" dict $in) | fromYaml) "ssl" -}}
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

{{- define "groundx.file.ingress" -}}
{{- $in := .Values.file | default dict -}}
{{- $ing := dig "ingress" dict $in -}}
{{- dig "ingress" dict $in | toYaml -}}
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
    "storageType"  (include "groundx.file.storageType" .)
    "username"     (include "groundx.file.username" .)
    "password"     (include "groundx.file.password" .)
    "port"         (include "groundx.file.port" .)
    "region"       (include "groundx.file.region" .)
    "scheme"       $scheme
    "ssl"          $ssl
    "token"        $token
  | toYaml -}}
{{- end }}
