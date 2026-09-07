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

{{- define "groundx.extract.agent.engine" -}}
{{- $extract := .Values.extract | default dict -}}
{{- $agent := dig "agent" dict $extract -}}
{{- $model := dig "model" dict $agent -}}
{{- $service := dig "serviceType" "" $agent | toString | lower | trim -}}
{{- $configured := deepCopy $model -}}
{{- range $input, $output := dict "apiKey" "apiKey" "apiBaseUrl" "baseUrl" "modelId" "engineId" -}}
  {{- if hasKey $agent $input -}}{{- $_ := set $configured $output (get $agent $input) -}}{{- end -}}
{{- end -}}
{{- $engine := dict -}}
{{- if ne $service "" -}}
  {{- $_ := set $configured "service" $service -}}
  {{- if eq $service "eyelevel" -}}
    {{- if not (hasKey $configured "engineId") -}}
      {{- $_ := set $configured "engineId" (include "groundx.summary.inference.model.name" . | trim) -}}
    {{- end -}}
    {{- $reasoning := include "groundx.summary.inference.model.reasoningEffort" . | trim -}}
    {{- if and (not (hasKey $configured "reasoningEffort")) (ne $reasoning "") -}}
      {{- $_ := set $configured "reasoningEffort" $reasoning -}}
    {{- end -}}
  {{- end -}}
  {{- $engine = include "groundx.engine.settings" (dict "root" . "name" "extract" "engine" $configured) | fromYaml -}}
{{- else -}}
  {{- $engines := include "groundx.engines" . | fromYaml -}}
  {{- $engine = get $engines "default" | default dict | deepCopy -}}
  {{- range $key, $value := $configured -}}
    {{- $_ := set $engine $key $value -}}
  {{- end -}}
{{- end -}}
{{- $engine | toYaml -}}
{{- end }}

{{- define "groundx.extract.file.settings" -}}
{{- $settings := include "groundx.file.settings" . | fromYaml | deepCopy -}}
{{- $extract := .Values.extract | default dict -}}
{{- $file := dig "file" dict $extract -}}
{{- range $input, $output := dict "bucketName" "bucketName" "region" "region" "serviceType" "storageType" -}}
  {{- $value := get $file $input -}}
  {{- if not (empty $value) -}}{{- $_ := set $settings $output $value -}}{{- end -}}
{{- end -}}
{{- range $key := list "username" "password" -}}
  {{- if hasKey $file $key -}}{{- $_ := set $settings $key (get $file $key) -}}{{- end -}}
{{- end -}}
{{- if not (empty (get $file "url")) -}}
  {{- $url := include "groundx.file.url.settings" $file | fromYaml -}}
  {{- range $key, $value := $url -}}{{- $_ := set $settings $key $value -}}{{- end -}}
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
{{- get (include "groundx.extract.file.settings" . | fromYaml) "bucketName" -}}
{{- end }}

{{- define "groundx.extract.file.domain" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "baseDomain" -}}
{{- end }}

{{- define "groundx.extract.file.serviceDependency" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "dependency" -}}
{{- end }}

{{- define "groundx.extract.file.password" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "password" -}}
{{- end }}

{{- define "groundx.extract.file.port" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "port" -}}
{{- end }}

{{- define "groundx.extract.file.region" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "region" -}}
{{- end }}

{{- define "groundx.extract.file.storageType" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "storageType" -}}
{{- end }}

{{- define "groundx.extract.file.ssl" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "bucketSSL" -}}
{{- end }}

{{- define "groundx.extract.file.username" -}}
{{- get (include "groundx.extract.file.settings" . | fromYaml) "username" -}}
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
