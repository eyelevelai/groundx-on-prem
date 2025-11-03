{{- define "groundx.extract.serviceName" -}}
{{- $in := .Values.extract | default dict -}}
{{ dig "serviceName" "extract" $in }}
{{- end }}

{{- define "groundx.extract.cacheDirectory" -}}
{{- $in := .Values.extract | default dict -}}
{{ dig "cacheDirectory" "/app/cache" $in }}
{{- end }}

{{- define "groundx.extract.callbackApiKey" -}}
{{- $in := .Values.extract | default dict -}}
{{ dig "callbackApiKey" (include "groundx.admin.username" .) $in }}
{{- end }}

{{- define "groundx.extract.callbackUrl" -}}
{{- $in := .Values.extract | default dict -}}
{{ dig "callbackUrl" (include "groundx.groundx.serviceUrl" .) $in }}
{{- end }}

{{- define "groundx.extract.create" -}}
{{- $in := .Values.extract | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.extract.file.existing" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{- if and (hasKey $efs "password") (hasKey $efs "serviceType") (hasKey $efs "url") (hasKey $efs "username") (hasKey $efs "bucketName") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.extract.file.bucketName" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{ dig "bucketName" (include "groundx.file.bucketName" .) $efs }}
{{- end }}

{{- define "groundx.extract.file.domain" -}}
{{- $in := .Values.extract | default dict -}}
{{- $ic := include "groundx.extract.file.existing" . -}}
{{- if eq $ic "true" -}}
  {{- $ex := dig "file" dict $in -}}
  {{- $url := dig "url" "" $ex -}}
  {{- $parts := splitList "://" $url -}}
  {{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
    {{ index $parts 1 }}
  {{- else -}}
    {{ include "groundx.file.serviceHost" . }}
  {{- end -}}
{{- else -}}
  {{ include "groundx.file.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.extract.file.serviceDependency" -}}
{{- $in := .Values.extract | default dict -}}
{{- $ic := include "groundx.extract.file.existing" . -}}
{{- if eq $ic "true" -}}
  {{- $ex := dig "file" dict $in -}}
  {{- $url := dig "url" "" $ex -}}
  {{- $parts := splitList "://" $url -}}
  {{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
    {{ index $parts 1 }}
  {{- else -}}
    {{ include "groundx.file.serviceDependency" . }}
  {{- end -}}
{{- else -}}
  {{ include "groundx.file.serviceDependency" . }}
{{- end -}}
{{- end }}

{{- define "groundx.extract.file.password" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{ dig "password" (include "groundx.file.password" .) $efs }}
{{- end }}

{{- define "groundx.extract.file.port" -}}
{{- $in := .Values.extract | default dict -}}
{{- $ic := include "groundx.extract.file.existing" . -}}
{{- if eq $ic "true" -}}
  {{- $ex := dig "file" dict $in -}}
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
  {{ include "groundx.file.port" . }}
{{- end -}}
{{- end }}

{{- define "groundx.extract.file.region" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{ dig "region" (include "groundx.file.region" .) $efs }}
{{- end }}

{{- define "groundx.extract.file.serviceType" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{ dig "serviceType" (include "groundx.file.serviceType" .) $efs }}
{{- end }}

{{- define "groundx.extract.file.ssl" -}}
{{- $ic := include "groundx.extract.file.existing" . -}}
{{- if eq $ic "true" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{- $url := dig "url" "" $efs -}}
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
{{- else -}}
{{ include "groundx.file.ssl" . }}
{{- end -}}
{{- end }}

{{- define "groundx.extract.file.username" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{ dig "username" (include "groundx.file.username" .) $efs }}
{{- end }}

{{- define "groundx.extract.file.settings" -}}
{{- $ic := include "groundx.extract.file.existing" . -}}
{{- if eq $ic "true" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{- $bucketSSL := include "groundx.extract.file.ssl" . -}}
{{- $bucketSSLStr := printf "%v" $bucketSSL -}}
{{- $bucketScheme := "http" -}}
{{- if eq $bucketSSLStr "true" -}}{{- $bucketScheme = "https" -}}{{- end -}}
{{- dict
    "baseDomain"   (include "groundx.extract.file.domain" .)
    "bucketDomain" (include "groundx.extract.file.domain" .)
    "bucketName"   (include "groundx.extract.file.bucketName" .)
    "bucketSSL"    $bucketSSL
    "password"     (include "groundx.extract.file.password" .)
    "port"         (include "groundx.extract.file.port" .)
    "region"       (include "groundx.extract.file.region" .)
    "scheme"       $bucketScheme
    "serviceType"  (include "groundx.extract.file.serviceType" .)
    "username"     (include "groundx.extract.file.username" .)
  | toYaml -}}
{{- else -}}
{{- include "groundx.file.settings" . -}}
{{- end -}}
{{- end }}

{{- define "groundx.extract.services" -}}
{{- $svcs := dict -}}
{{- $ic := include "groundx.extract.agent.create" . -}}
{{- if eq $ic "true" -}}
{{- $_ := set $svcs "extract.agent" "extract.agent" -}}
{{- end -}}
{{- $im := include "groundx.extract.download.create" . -}}
{{- if eq $im "true" -}}
{{- $_ := set $svcs "extract.download" "extract.download" -}}
{{- end -}}
{{- $is := include "groundx.extract.save.create" . -}}
{{- if eq $is "true" -}}
{{- $_ := set $svcs "extract.save" "extract.save" -}}
{{- end -}}
{{- $svcs | toYaml -}}
{{- end }}
