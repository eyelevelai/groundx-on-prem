{{- define "groundx.largeFileDeliver.create" -}}
{{- $in := .Values.largeFileDeliver | default dict -}}
{{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.largeFileDeliver.serviceName" -}}
{{- $in := .Values.largeFileDeliver | default dict -}}
{{ dig "serviceName" "large-file-delivery" $in }}
{{- end }}

{{- define "groundx.largeFileDeliver.containerPort" -}}
{{- $in := .Values.largeFileDeliver | default dict -}}
{{ dig "containerPort" 8080 $in }}
{{- end }}

{{- define "groundx.largeFileDeliver.replicas" -}}
{{- $in := .Values.largeFileDeliver | default dict -}}
desired: {{ dig "replicas" "desired" 1 $in }}
{{- end }}

{{- define "groundx.largeFileDeliver.settings" -}}
{{- $in := .Values.largeFileDeliver -}}
{{- $cfg := dict
  "dependencies" (dict "groundx" "groundx")
  "image" (required "largeFileDeliver.image is required" $in.image)
  "name" (include "groundx.largeFileDeliver.serviceName" .)
  "node" (dig "node" (include "groundx.node.cpuOnly" .) $in)
  "port" (include "groundx.largeFileDeliver.containerPort" .)
  "pull" (dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in)
  "replicas" (include "groundx.largeFileDeliver.replicas" . | fromYaml)
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
  {{- $name := printf "large-file-credential-%d" $idx -}}
  {{- $mounts = append $mounts (dict "name" $name "mountPath" (printf "/var/run/groundx/large-file/%s" $ref) "readOnly" true) -}}
  {{- $volumes = append $volumes (dict "name" $name "secret" (dict "secretName" $credential.secretName "items" (list (dict "key" $credential.secretKey "path" "credentials.json")))) -}}
{{- end -}}
{{- $_ := set $cfg "volumeMounts" $mounts -}}
{{- $_ := set $cfg "volumes" $volumes -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.largeFileDeliver.config" -}}
{{- $in := .Values.largeFileDeliver -}}
largeFileRouting:
  {{- $in.counting | toYaml | nindent 2 }}
largeFileDelivery:
  maxUploadDuration: {{ $in.maxUploadDuration | quote }}
  concurrency: {{ $in.concurrency }}
  credentials:
    {{- range $ref, $credential := $in.credentials }}
    {{ $ref }}:
      credentialsFile: {{ printf "/var/run/groundx/large-file/%s/credentials.json" $ref }}
    {{- end }}
largeFileDeliveryServer:
  maxConcurrent: {{ $in.concurrency }}
  port: {{ include "groundx.largeFileDeliver.containerPort" . }}
  serviceName: {{ include "groundx.largeFileDeliver.serviceName" . }}
{{- end }}
