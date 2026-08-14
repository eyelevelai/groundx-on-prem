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

{{- define "groundx.extract.terminalAgentTraceEnabled" -}}
{{- $root := .root -}}
{{- $podName := .pod -}}
{{- $extract := $root.Values.extract | default dict -}}
{{- $pod := get $extract $podName | default dict -}}
{{- $enabled := false -}}
{{- if hasKey $extract "terminalAgentTraceEnabled" -}}
  {{- $enabled = get $extract "terminalAgentTraceEnabled" -}}
{{- end -}}
{{- if hasKey $pod "terminalAgentTraceEnabled" -}}
  {{- $enabled = get $pod "terminalAgentTraceEnabled" -}}
{{- end -}}
{{- $enabled | toString -}}
{{- end }}

{{- define "groundx.extract.serviceUrl" -}}
{{- $in := .Values.extract | default dict -}}
{{- $ur := dig "callbackUrl" (include "groundx.groundx.serviceUrl" .) $in -}}
{{- $parts := splitList "://" $ur -}}
{{- $scheme := "http" -}}
{{- $host := "" -}}
{{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
  {{- $scheme = index $parts 0 -}}
  {{- $hostWithPath := index $parts 1 -}}
  {{- $host = (splitList "/" $hostWithPath | first) -}}
{{- else -}}
  {{- $host = $ur -}}
{{- end -}}
{{ printf "%s://%s/api" $scheme $host }}
{{- end }}

{{- define "groundx.extract.create" -}}
{{- $in := .Values.extract | default dict -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.extract.file.effectiveSettings" -}}
{{- $settings := include "groundx.file.settings" . | fromYaml | deepCopy -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{- $bucketName := dig "bucketName" "" $efs -}}
{{- if not (empty $bucketName) -}}{{- $_ := set $settings "bucketName" $bucketName -}}{{- end -}}
{{- $region := dig "region" "" $efs -}}
{{- if not (empty $region) -}}{{- $_ := set $settings "region" $region -}}{{- end -}}
{{- $storageType := dig "serviceType" "" $efs -}}
{{- if not (empty $storageType) -}}{{- $_ := set $settings "storageType" $storageType -}}{{- end -}}
{{- if hasKey $efs "username" -}}{{- $_ := set $settings "username" (get $efs "username") -}}{{- end -}}
{{- if hasKey $efs "password" -}}{{- $_ := set $settings "password" (get $efs "password") -}}{{- end -}}
{{- $url := dig "url" "" $efs -}}
{{- if not (empty $url) -}}
  {{- $parts := splitList "://" $url -}}
  {{- $domain := $url -}}
  {{- $scheme := "http" -}}
  {{- if and (kindIs "slice" $parts) (eq (len $parts) 2) -}}
    {{- $scheme = index $parts 0 -}}
    {{- $domain = index $parts 1 -}}
  {{- end -}}
  {{- $ssl := eq $scheme "https" -}}
  {{- $_ := set $settings "baseDomain" $domain -}}
  {{- $_ := set $settings "bucketDomain" $domain -}}
  {{- $_ := set $settings "bucketSSL" $ssl -}}
  {{- $_ := set $settings "scheme" $scheme -}}
  {{- $_ := set $settings "ssl" $ssl -}}
  {{- $dependencyParts := splitList ":" $domain -}}
  {{- if and (kindIs "slice" $dependencyParts) (eq (len $dependencyParts) 2) -}}
    {{- $_ := set $settings "dependency" (index $dependencyParts 0) -}}
  {{- else -}}
    {{- $_ := set $settings "dependency" $domain -}}
  {{- end -}}
  {{- $rawPort := dig "port" "" $efs -}}
  {{- $port := -1 -}}
  {{- if kindIs "string" $rawPort -}}
    {{- $port = int $rawPort -}}
  {{- else if kindIs "int" $rawPort -}}
    {{- $port = $rawPort -}}
  {{- end -}}
  {{- if gt $port 0 -}}
    {{- $_ := set $settings "port" $port -}}
  {{- else if and (kindIs "slice" $dependencyParts) (eq (len $dependencyParts) 2) -}}
    {{- $_ := set $settings "port" (index $dependencyParts 1) -}}
  {{- else if $ssl -}}
    {{- $_ := set $settings "port" 443 -}}
  {{- else -}}
    {{- $_ := set $settings "port" 80 -}}
  {{- end -}}
{{- else -}}
  {{- $rawPort := dig "port" "" $efs -}}
  {{- $port := -1 -}}
  {{- if kindIs "string" $rawPort -}}
    {{- $port = int $rawPort -}}
  {{- else if kindIs "int" $rawPort -}}
    {{- $port = $rawPort -}}
  {{- end -}}
  {{- if gt $port 0 -}}{{- $_ := set $settings "port" $port -}}{{- end -}}
{{- end -}}
{{- $_ := set $settings "serviceType" (get $settings "storageType") -}}
{{- $settings | toYaml -}}
{{- end }}

{{- define "groundx.extract.file.existing" -}}
{{- $in := .Values.extract | default dict -}}
{{- $efs := dig "file" dict $in -}}
{{- $url := dig "url" "" $efs -}}
{{- $accountExisting := include "groundx.file.existing" . | trim | lower -}}
{{- if or (not (empty $url)) (eq $accountExisting "true") -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.extract.file.bucketName" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "bucketName" -}}
{{- end }}

{{- define "groundx.extract.file.domain" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "baseDomain" -}}
{{- end }}

{{- define "groundx.extract.file.serviceDependency" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "dependency" -}}
{{- end }}

{{- define "groundx.extract.file.password" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "password" -}}
{{- end }}

{{- define "groundx.extract.file.port" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "port" -}}
{{- end }}

{{- define "groundx.extract.file.region" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "region" -}}
{{- end }}

{{- define "groundx.extract.file.storageType" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "storageType" -}}
{{- end }}

{{- define "groundx.extract.file.ssl" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "bucketSSL" -}}
{{- end }}

{{- define "groundx.extract.file.username" -}}
{{- get (include "groundx.extract.file.effectiveSettings" . | fromYaml) "username" -}}
{{- end }}

{{- define "groundx.extract.file.settings" -}}
{{- include "groundx.extract.file.effectiveSettings" . -}}
{{- end }}

{{- define "groundx.extract.services" -}}

{{- $svcs := dict -}}

{{- $services := list
  "extract.agent"
  "extract.download"
  "extract.save"
-}}

{{- range $svc := $services }}
  {{- $tpl := printf "groundx.%s.create" $svc -}}
  {{- $il := include $tpl $ -}}
  {{- if eq $il "true" -}}
    {{- $_ := set $svcs $svc $svc -}}
  {{- end -}}
{{- end }}

{{- $svcs | toYaml -}}

{{- end }}
