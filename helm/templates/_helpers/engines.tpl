{{- define "groundx.engine.resolve" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $engine := deepCopy (.engine | default dict) -}}
{{- $summary := $root.Values.summary | default dict -}}
{{- $existing := dig "existing" dict $summary -}}
{{- $existingConfigured := eq (include "groundx.summary.existingConfigured" $root) "true" -}}
{{- $explicitService := coalesce (get $engine "service") (get $engine "serviceType") "" | default "" | toString | lower | trim -}}
{{- $service := coalesce $explicitService (include "groundx.summary.serviceType" $root) | default "eyelevel" | toString | lower | trim -}}
{{- $engineBaseUrl := get $engine "baseUrl" | default "" | toString | trim -}}
{{- $localUrl := include "groundx.summary.api.serviceUrl" $root | trim -}}
{{- $local := and (eq $service "eyelevel") (or (eq $engineBaseUrl $localUrl) (and (eq $engineBaseUrl "") (or (not $existingConfigured) (eq $explicitService "eyelevel")))) -}}
{{- $inheritsExisting := or (eq $name "default") (eq $explicitService "") -}}
{{- $_ := set $engine "service" $service -}}
{{- if ne $engineBaseUrl "" -}}
  {{- $_ := set $engine "baseUrl" (get $engine "baseUrl") -}}
{{- else if $local -}}
  {{- $_ := set $engine "baseUrl" $localUrl -}}
{{- else if and $inheritsExisting (ne (dig "url" "" $existing | toString | trim) "") -}}
  {{- $_ := set $engine "baseUrl" (get $existing "url") -}}
{{- end -}}
{{- if not (hasKey $engine "apiKey") -}}
  {{- if $local -}}
    {{- $localApiKey := include "groundx.admin.apiKey" $root | trim -}}
    {{- if ne $localApiKey "" -}}
      {{- $_ := set $engine "apiKey" $localApiKey -}}
    {{- end -}}
  {{- else if and $inheritsExisting (hasKey $existing "apiKey") -}}
    {{- $_ := set $engine "apiKey" (get $existing "apiKey") -}}
  {{- end -}}
{{- end -}}
{{- $engine | toYaml -}}
{{- end }}

{{- define "groundx.engines" -}}
{{- $root := . -}}
{{- $in := .Values.engines | default dict -}}
{{- if eq (len $in) 0 -}}
{{- $replicas := (include "groundx.summary.inference.replicas" . | fromYaml) -}}
{{- $desired := get $replicas "desired" -}}
{{- $scaled := mul $desired 2 -}}
{{- $eng := dict
  "dataType"        (include "groundx.summary.inference.model.dataType" .)
  "engineId"        (include "groundx.summary.inference.model.name" .)
  "maxInputTokens"  (include "groundx.summary.inference.model.maxInputTokens" .)
  "maxOutputTokens" (include "groundx.summary.inference.model.maxOutputTokens" .)
  "maxRequests"     ($scaled)
  "requestLimit"    ($scaled)
  "vision"          (true)
-}}
{{- $in = dict "default" $eng -}}
{{- end -}}
{{- $resolved := dict -}}
{{- range $name, $engine := $in -}}
  {{- $_ := set $resolved $name (include "groundx.engine.resolve" (dict "root" $root "name" $name "engine" $engine) | fromYaml) -}}
{{- end -}}
{{- $resolved | toYaml -}}
{{- end }}

{{- define "groundx.hasCustomEngines" -}}
{{- $in := .Values.engines | default list -}}
{{- if gt (len $in) 0 }}
true
{{- else -}}
false
{{- end -}}
{{- end }}
