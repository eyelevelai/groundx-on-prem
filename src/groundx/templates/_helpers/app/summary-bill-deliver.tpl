{{- define "groundx.summaryBillDeliver.create" -}}
{{- $in := .Values.summaryBillDeliver | default dict -}}
{{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.summaryBillDeliver.serviceName" -}}
{{- $in := .Values.summaryBillDeliver | default dict -}}
{{ dig "serviceName" "summary-bill-delivery" $in }}
{{- end }}

{{- define "groundx.summaryBillDeliver.containerPort" -}}
{{- $in := .Values.summaryBillDeliver | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.summaryBillDeliver.replicas" -}}
{{- $in := .Values.summaryBillDeliver | default dict -}}
desired: {{ dig "replicas" "desired" 1 $in }}
{{- end }}

{{- define "groundx.summaryBillDeliver.settings" -}}
{{- $in := .Values.summaryBillDeliver -}}
{{- $cfg := dict
  "dependencies" (dict "groundx" "groundx")
  "image" (required "summaryBillDeliver.image is required" $in.image)
  "name" (include "groundx.summaryBillDeliver.serviceName" .)
  "node" (dig "node" (include "groundx.node.cpuOnly" .) $in)
  "port" (include "groundx.summaryBillDeliver.containerPort" .)
  "pull" (dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in)
  "replicas" (include "groundx.summaryBillDeliver.replicas" . | fromYaml)
-}}
{{- $san := dig "serviceAccount" "name" (include "groundx.serviceAccountName" .) $in -}}
{{- if $san -}}{{- $_ := set $cfg "serviceAccountName" $san -}}{{- end -}}
{{- range $key := list "affinity" "annotations" "containerSecurityContext" "labels" "nodeSelector" "resources" "securityContext" "tolerations" -}}
  {{- if hasKey $in $key -}}{{- $_ := set $cfg $key (get $in $key) -}}{{- end -}}
{{- end -}}
{{- $mounts := list -}}
{{- $volumes := list -}}
{{- range $idx, $ref := keys $in.credentials | sortAlpha -}}
  {{- $credential := get $in.credentials $ref -}}
  {{- $name := printf "summary-bill-credential-%d" $idx -}}
  {{- $mounts = append $mounts (dict "name" $name "mountPath" (printf "/var/run/groundx/summary-bill/%s" $ref) "readOnly" true) -}}
  {{- $volumes = append $volumes (dict "name" $name "secret" (dict "secretName" $credential.secretName "items" (list (dict "key" $credential.secretKey "path" "credentials.json")))) -}}
{{- end -}}
{{- $_ := set $cfg "volumeMounts" $mounts -}}
{{- $_ := set $cfg "volumes" $volumes -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.summaryBillDeliver.config" -}}
{{- $in := .Values.summaryBillDeliver -}}
summaryBillRouting:
  {{- $in.counting | toYaml | nindent 2 }}
summaryBillDelivery:
  maxUploadDuration: {{ $in.maxUploadDuration | quote }}
  concurrency: {{ $in.concurrency }}
  credentials:
    {{- range $ref, $credential := $in.credentials }}
    {{ $ref }}:
      credentialsFile: {{ printf "/var/run/groundx/summary-bill/%s/credentials.json" $ref }}
    {{- end }}
summaryBillDeliveryServer:
  maxConcurrent: {{ $in.concurrency }}
  port: {{ include "groundx.summaryBillDeliver.containerPort" . }}
  serviceName: {{ include "groundx.summaryBillDeliver.serviceName" . }}
{{- end }}
