{{- define "groundx.file.create" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- or (not (hasKey $ex "domain")) (not (hasKey $ex "port")) (not (hasKey $ex "ssl")) -}}
{{- end }}

{{- define "groundx.file.domain" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $in := .Values.file.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "domain" "" $ex) (dig "customDomain" "" $in) (printf "%s.%s.svc.cluster.local" (dig "serviceName" "minio" $in) $ns) -}}
{{- end }}

{{- define "groundx.file.port" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $in := .Values.file.internal | default dict -}}
{{- coalesce (dig "port" "" $ex) (dig "port" 9000 $in) -}}
{{- end }}

{{- define "groundx.file.ssl" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $in := .Values.file.internal | default dict -}}
{{- $lb := dig "load_balancer" dict $in -}}
{{- $lbssl := (hasKey $lb "ssl") | ternary (dig "ssl" "" $lb) "" -}}
{{- coalesce (dig "ssl" "" $ex) $lbssl "false" -}}
{{- end }}

{{- define "groundx.file.settings" -}}
{{- $ex := .Values.file.existing | default dict -}}
{{- $in := .Values.file.internal | default dict -}}
{{- $f  := .Values.file | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- $svc := dig "serviceName" "minio" $in -}}
{{- $domain := include "groundx.file.domain" . -}}
{{- $ssl := include "groundx.file.ssl" . -}}
{{- $bucketDomain := printf "%s.%s.svc.cluster.local" $svc $ns -}}
{{- $sslStr := printf "%v" $ssl -}}
{{- $scheme := "http" -}}
{{- if eq $sslStr "true" -}}{{- $scheme = "https" -}}{{- end -}}
{{- $extBucketSSL := coalesce (dig "ssl" "" $ex) false -}}
{{- $extBucketSSLStr := printf "%v" $extBucketSSL -}}
{{- $bucketScheme := "http" -}}
{{- if eq $extBucketSSLStr "true" -}}{{- $bucketScheme = "https" -}}{{- end -}}
{{- dict
    "baseDomain"   (coalesce (dig "domain" "" $ex) $domain)
    "bucketName"   (coalesce (dig "bucketName" "" $f) "eyelevel")
    "bucketDomain" $bucketDomain
    "bucketScheme" $bucketScheme
    "bucketSSL"    (coalesce (dig "ssl" "" $ex) $ssl "false")
    "dependency"   (coalesce (dig "domain" "" $ex) (printf "%s-tenant-hl.%s.svc.cluster.local" $svc $ns))
    "serviceType"  (dig "serviceType" "" $f)
    "username"     (dig "username" "" $f)
    "password"     (dig "password" "" $f)
    "port"         (include "groundx.file.port" .)
    "scheme"       $scheme
    "ssl"          $ssl
  | toYaml -}}
{{- end }}
