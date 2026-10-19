{{- define "groundx.postProcess.create" -}}
{{- $in := .Values.postProcess | default dict -}}
{{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.postProcess.serviceName" -}}
{{- $in := .Values.postProcess | default dict -}}
{{ dig "serviceName" "post-process" $in }}
{{- end }}

{{- define "groundx.postProcess.containerPort" -}}
{{- $in := .Values.postProcess | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.postProcess.replicas" -}}
{{- $in := .Values.postProcess | default dict -}}
desired: {{ dig "replicas" "desired" 1 $in }}
{{- end }}

{{- define "groundx.postProcess.settings" -}}
{{- $in := .Values.postProcess -}}
{{- $cfg := dict
  "dependencies" (dict "groundx" "groundx")
  "image" (required "postProcess.image is required" $in.image)
  "name" (include "groundx.postProcess.serviceName" .)
  "node" (dig "node" (include "groundx.node.cpuOnly" .) $in)
  "port" (include "groundx.postProcess.containerPort" .)
  "pull" (dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in)
  "replicas" (include "groundx.postProcess.replicas" . | fromYaml)
-}}
{{- $san := dig "serviceAccount" "name" (include "groundx.serviceAccountName" .) $in -}}
{{- if $san -}}{{- $_ := set $cfg "serviceAccountName" $san -}}{{- end -}}
{{- range $key := list "affinity" "annotations" "containerSecurityContext" "labels" "nodeSelector" "resources" "securityContext" "tolerations" "topologySpreadConstraints" "disruptionBudget" -}}
  {{- if hasKey $in $key -}}{{- $_ := set $cfg $key (get $in $key) -}}{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.postProcess.config" -}}
manualDeliveryRetry: {{ .Values.postProcess.retryEnabled | default false }}
postProcessFileServer:
  maxConcurrent: {{ .Values.postProcess.concurrency }}
  port: {{ include "groundx.postProcess.containerPort" . }}
  serviceName: {{ include "groundx.postProcess.serviceName" . }}
{{- end }}
