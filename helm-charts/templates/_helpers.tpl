{{- define "groundx.ns" -}}
{{- if .Values.namespace -}}{{ .Values.namespace }}{{- else -}}{{ .Release.Namespace }}{{- end -}}
{{- end }}

{{- define "groundx.isOpenshift" -}}
{{- eq (dig "type" "" .Values.cluster) "openshift" -}}
{{- end }}

{{- define "groundx.createSymlink" -}}
{{- $t := dig "type" "" .Values.cluster -}}
{{- and (ne $t "openshift") (ne $t "minikube") -}}
{{- end }}

{{- define "groundx.cache.create" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- or (empty (dig "addr" "" $ex)) (empty (dig "isCluster" "" $ex)) (empty (dig "port" "" $ex)) -}}
{{- end }}

{{- define "groundx.cache.addr" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "addr" "" $ex) (printf "%s.%s.svc.cluster.local" (dig "serviceName" "redis" $in) $ns) -}}
{{- end }}

{{- define "groundx.cache.isCluster" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- $ic := coalesce (dig "isCluster" "" $ex) (dig "isCluster" "" $in) -}}
{{- if eq (printf "%v" $ic) "true" -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.cache.notCluster" -}}
{{- $ic := include "groundx.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.cache.port" -}}
{{- $ex := .Values.cache.existing | default dict -}}
{{- $in := .Values.cache.internal | default dict -}}
{{- coalesce (dig "port" "" $ex) (dig "port" 6379 $in) -}}
{{- end }}

{{- define "groundx.metrics.cache.create" -}}
{{- and (include "groundx.cache.create" . | fromYaml) (dig "metrics" "enabled" false .Values.cache) -}}
{{- end }}

{{- define "groundx.metrics.cache.addr" -}}
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- $in := dig "internal" dict $m -}}
{{- $ns := include "groundx.ns" . -}}
{{- if (dig "enabled" false $m) -}}
  {{- coalesce (dig "addr" "" $ex) (printf "%s-%s.%s.svc.cluster.local" (dig "serviceName" "redis" (.Values.cache.internal | default dict)) (dig "serviceName" "metrics" $in) $ns) -}}
{{- else -}}
  {{- include "groundx.cache.addr" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.isCluster" -}}
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- $in := dig "internal" dict $m -}}
{{- if (dig "enabled" false $m) -}}
  {{- $ic := coalesce (dig "isCluster" "" $ex) (dig "isCluster" "" $in) -}}
  {{- if eq (printf "%v" $ic) "true" -}}true{{- else -}}false{{- end -}}
{{- else -}}
  {{- include "groundx.cache.isCluster" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.notCluster" -}}
{{- $ic := include "groundx.metrics.cache.isCluster" . | trim | lower -}}
{{- if eq $ic "true" -}}false{{- else -}}true{{- end -}}
{{- end }}

{{- define "groundx.metrics.cache.port" -}}
{{- $m  := .Values.cache.metrics | default dict -}}
{{- $ex := dig "existing" dict $m -}}
{{- $in := dig "internal" dict $m -}}
{{- if (dig "enabled" false $m) -}}
  {{- coalesce (dig "port" "" $ex) (dig "port" 6379 $in) -}}
{{- else -}}
  {{- include "groundx.cache.port" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.create" -}}
{{- $ex := dig "existing" dict .Values.db -}}
{{- or (empty (dig "port" "" $ex)) (empty (dig "ro" "" $ex)) (empty (dig "rw" "" $ex)) -}}
{{- end }}

{{- define "groundx.db.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := (.Values.db.internal.serviceName | default "") -}}
{{- printf "%s-cluster-pxc-db-haproxy.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.db.ro" -}}
{{- $db := .Values.db | default dict -}}
{{- $ext := dig "existing" "ro" "" $db -}}
{{- if $ext -}}
{{- $ext -}}
{{- else -}}
{{- include "groundx.db.serviceHost" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.rw" -}}
{{- $db := .Values.db | default dict -}}
{{- $ext := dig "existing" "rw" "" $db -}}
{{- if $ext -}}
{{- $ext -}}
{{- else -}}
{{- include "groundx.db.serviceHost" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.db.port" -}}
{{- $db := .Values.db | default dict -}}
{{- $ext := dig "existing" "port" "" $db -}}
{{- if $ext -}}
{{- $ext -}}
{{- else -}}
{{- dig "internal" "port" 3306 $db -}}
{{- end -}}
{{- end }}

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

{{- define "groundx.search.create" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $hasSearch := not (.Values.ingestOnly | default false) -}}
{{- and $hasSearch (or (not (hasKey $ex "domain")) (not (hasKey $ex "url")) (not (hasKey $ex "port"))) -}}
{{- end }}

{{- define "groundx.search.baseDomain" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $in := .Values.search.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "domain" "" $ex) (printf "%s-cluster-master.%s.svc.cluster.local" (dig "serviceName" "search" $in) $ns) -}}
{{- end }}

{{- define "groundx.search.port" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $in := .Values.search.internal | default dict -}}
{{- coalesce (dig "port" "" $ex) (dig "port" 9200 $in) -}}
{{- end }}

{{- define "groundx.search.baseURL" -}}
{{- $ex := .Values.search.existing | default dict -}}
{{- $in := .Values.search.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- $svc := dig "serviceName" "search" $in -}}
{{- $port := include "groundx.search.port" . -}}
{{- coalesce (dig "url" "" $ex) (printf "https://%s-cluster-master.%s.svc.cluster.local:%v" $svc $ns $port) -}}
{{- end }}

{{- define "groundx.stream.create" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- or (not (hasKey $ex "domain")) (not (hasKey $ex "port")) -}}
{{- end }}

{{- define "groundx.stream.baseDomain" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- $in := .Values.stream.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "domain" "" $ex) (printf "%s-cluster-kafka-bootstrap.%s.svc.cluster.local" (dig "serviceName" "kafka" $in) $ns) -}}
{{- end }}

{{- define "groundx.stream.port" -}}
{{- $ex := .Values.stream.existing | default dict -}}
{{- $in := .Values.stream.internal | default dict -}}
{{- coalesce (dig "port" "" $ex) (dig "port" 9092 $in) -}}
{{- end }}

{{- define "groundx.summary.create" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- $stype := lower (coalesce (dig "serviceType" "" $ex) "on-prem") -}}
{{- $stypeNorm := replace $stype "-" "" -}}
{{- and (or (empty (dig "apiKey" "" $ex)) (empty (dig "url" "" $ex))) (ne $stypeNorm "openai") -}}
{{- end }}

{{- define "groundx.summary.apiKey" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- coalesce (dig "apiKey" "" $ex) (.Values.admin.apiKey | default "") -}}
{{- end }}

{{- define "groundx.summary.baseURL" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- $in := .Values.summary.internal | default dict -}}
{{- $ns := include "groundx.ns" . -}}
{{- coalesce (dig "url" "" $ex) (printf "http://%s-api.%s.svc.cluster.local" (dig "serviceName" "summary" $in) $ns) -}}
{{- end }}

{{- define "groundx.summary.serviceType" -}}
{{- $ex := .Values.summary.existing | default dict -}}
{{- coalesce (dig "serviceType" "" $ex) "on-prem" -}}
{{- end }}
