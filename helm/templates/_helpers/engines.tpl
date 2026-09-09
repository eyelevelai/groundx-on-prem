{{- define "groundx.engine.settings" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $engine := deepCopy (.engine | default dict) -}}
{{- $summary := $root.Values.summary | default dict -}}
{{- $existing := dig "existing" dict $summary -}}
{{- $hasExisting := eq (include "groundx.summary.existing" $root) "true" -}}
{{- $explicitService := coalesce (get $engine "service") (get $engine "serviceType") "" | default "" | toString | lower | trim -}}
{{- $service := coalesce $explicitService (include "groundx.summary.serviceType" $root) | default "eyelevel" | toString | lower | trim -}}
{{- $engineBaseUrl := get $engine "baseUrl" | default "" | toString | trim -}}
{{- $localUrl := include "groundx.summary.api.serviceUrl" $root | trim -}}
{{- $local := and (eq $service "eyelevel") (or (eq $engineBaseUrl $localUrl) (and (eq $engineBaseUrl "") (or (not $hasExisting) (eq $explicitService "eyelevel")))) -}}
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
{{- if and (eq (include "groundx.summary.existing" .) "true") (eq (len $in) 0) -}}
  {{- fail "explicit summary configuration requires engines.<name>.engineId" -}}
{{- end -}}
{{- range $name, $engine := $in -}}
  {{- if eq (get $engine "engineId" | default "" | toString | trim) "" -}}
    {{- fail (printf "summary engine %s requires engines.%s.engineId" $name $name) -}}
  {{- end -}}
{{- end -}}
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
  {{- $_ := set $resolved $name (include "groundx.engine.settings" (dict "root" $root "name" $name "engine" $engine) | fromYaml) -}}
{{- end -}}
{{- $resolved | toYaml -}}
{{- end }}

{{- define "groundx.engine.create" -}}
{{- $localUrl := include "groundx.summary.api.serviceUrl" .root | trim -}}
{{- $engine := .engine -}}
{{- and (eq (get $engine "service") "eyelevel") (eq (get $engine "baseUrl" | default "" | toString | trim) $localUrl) -}}
{{- end }}

{{- define "groundx.hasCustomEngines" -}}
{{- $in := .Values.engines | default list -}}
{{- if gt (len $in) 0 }}
true
{{- else -}}
false
{{- end -}}
{{- end }}
