{{- define "groundx.google.configured" -}}
{{- $in := .Values.google | default dict -}}
{{- if or (dig "credentials" "" $in) (dig "existingSecret" "" $in) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.google.secretName" -}}
{{- $in := .Values.google | default dict -}}
{{- if ne (include "groundx.google.configured" .) "true" -}}
{{- fail "sharedGoogle requires google.credentials or google.existingSecret" -}}
{{- end -}}
{{- coalesce (dig "existingSecret" "" $in) "google-credentials" -}}
{{- end }}

{{- define "groundx.google.secretKey" -}}
{{- $in := .Values.google | default dict -}}
{{- dig "secretKey" "credentials.json" $in -}}
{{- end }}

{{- define "groundx.layout.ocr.sharedGoogle" -}}
{{- if and (eq (include "groundx.layout.ocr.create" .) "true") (eq (include "groundx.layout.ocr.type" .) "google") (eq (include "groundx.layout.ocr.credentials" .) "") (eq (include "groundx.google.configured" .) "true") -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.largeFileDeliver.sharedGoogle" -}}
{{- $used := false -}}
{{- $in := .Values.largeFileDeliver | default dict -}}
{{- if (dig "enabled" false $in) -}}
  {{- range $credential := (dig "credentials" dict $in) -}}
    {{- if (dig "sharedGoogle" false $credential) -}}{{- $used = true -}}{{- end -}}
  {{- end -}}
{{- end -}}
{{- $used -}}
{{- end }}

{{- define "groundx.google.managed" -}}
{{- $in := .Values.google | default dict -}}
{{- $used := or (eq (include "groundx.layout.ocr.sharedGoogle" .) "true") (eq (include "groundx.largeFileDeliver.sharedGoogle" .) "true") -}}
{{- if and $used (dig "credentials" "" $in) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.google.credentials" -}}
{{- $path := .Values.google.credentials -}}
{{- if not (.Files.Glob $path) -}}
{{- fail (printf "google.credentials file not found at path: %s" $path) -}}
{{- end -}}
{{- .Files.Get $path -}}
{{- end }}
