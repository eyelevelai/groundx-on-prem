{{- define "groundx.file.serviceName" -}}
{{- $in := .Values.file | default dict -}}
{{ dig "serviceName" "file" $in }}
{{- end }}

{{- define "groundx.file.existing" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{ not (empty (dig "domain" "" $ex)) }}
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

{{- define "groundx.file.domain" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "domain" "" $ex }}
{{- else if and (hasKey $in "customDomain") (not (empty $in.customDomain)) }}
{{ $in.customDomain }}
{{- else -}}
{{ include "groundx.file.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.file.serviceDependency" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.file.serviceName" . -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ include "groundx.file.domain" . }}
{{- else -}}
{{- printf "%s-tenant-hl.%s.svc.cluster.local" $name $ns -}}
{{- end -}}
{{- end }}

{{- define "groundx.file.port" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" "" $ex }}
{{- else -}}
{{ dig "port" 9000 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.file.bucketSsl" -}}
{{- $in := .Values.file | default dict -}}
{{- $lb := .Values.file.loadBalancer | default dict -}}
{{- if hasKey $lb "ssl" }}
{{ $lb.ssl }}
{{- else -}}
{{ dig "ssl" "false" $in }}
{{- end -}}
{{- end }}

{{- define "groundx.file.ssl" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $in := .Values.file | default dict -}}
{{- $ic := include "groundx.file.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "ssl" "false" $ex }}
{{- else -}}
{{ dig "ssl" "false" $in }}
{{- end -}}
{{- end }}

{{- define "groundx.file.loadBalancer" -}}
{{- $in := .Values.file.loadBalancer | default dict -}}
{{- if hasKey $in "port" }}
{{- dict
    "port"       (dig "port" "" $in)
    "ssl"        (dig "ssl" "" $in)
    "targetPort" (include "groundx.file.port" .)
    "timeout"    (dig "timeout" "" $in)
  | toYaml -}}
{{- end -}}
{{- end }}

{{- define "groundx.file.settings" -}}
{{- $in := .Values.file | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- $svc := dig "serviceName" "minio" $in -}}
{{- $ssl := include "groundx.file.ssl" . -}}
{{- $bucketDomain := printf "%s.%s.svc.cluster.local" $svc $ns -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- $extBucketSSL := include "groundx.file.bucketSsl" . -}}
{{- $extBucketSSLStr := printf "%v" $extBucketSSL -}}
{{- $bucketScheme := "http" -}}
{{- if eq $extBucketSSLStr "true" -}}{{- $bucketScheme = "https" -}}{{- end -}}
{{- dict
    "baseDomain"   (include "groundx.file.domain" .)
    "bucketName"   (coalesce (dig "bucketName" "" $in) "eyelevel")
    "bucketDomain" (include "groundx.file.serviceHost" .)
    "bucketScheme" $bucketScheme
    "bucketSSL"    (include "groundx.file.bucketSsl" .)
    "dependency"   (include "groundx.file.serviceDependency" .)
    "serviceType"  (dig "serviceType" "" $in)
    "username"     (dig "username" "" $in)
    "password"     (dig "password" "" $in)
    "port"         (include "groundx.file.port" .)
    "scheme"       $scheme
    "ssl"          $ssl
  | toYaml -}}
{{- end }}
