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

{{- define "groundx.environment" -}}
{{ .Values.environment | default "prod" }}
{{- end }}

{{- define "groundx.imageRepository" -}}
{{- $in := .Values.admin | default dict -}}
{{- $repo := dig "imageRepository" "" $in -}}
{{- if ne $repo "" -}}
{{ $repo }}
{{- else -}}
public.ecr.aws/c9r4x6y5
{{- end -}}
{{- end }}

{{- define "groundx.busybox.image" -}}
{{- printf "%s/eyelevel/busybox:latest" (include "groundx.imageRepository" .) -}}
{{- end }}

{{- define "groundx.busybox.pull" -}}
Always
{{- end }}