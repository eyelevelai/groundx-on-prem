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

{{- define "groundx.imageRepository" -}}
{{- $in := .Values.admin | default dict -}}
{{- $repo := dig "imageRepository" "" $in -}}
{{- if $repo -}}
{{ $repo }}
{{- else -}}
public.ecr.aws/c9r4x6y5
{{- end -}}
{{- end }}