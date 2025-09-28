{{- define "groundx.ns" -}}
{{ coalesce .Values.namespace .Release.Namespace "eyelevel" }}
{{- end }}

{{- define "groundx.admin.apiKey" -}}
{{- $b := .Values.admin | default dict -}}
{{- dig "apiKey" "00000000-0000-0000-0000-000000000000" $b -}}
{{- end }}

{{- define "groundx.admin.email" -}}
{{- $b := .Values.admin | default dict -}}
{{- dig "email" "support@mycorp.net" $b -}}
{{- end }}

{{- define "groundx.admin.password" -}}
{{- $b := .Values.admin | default dict -}}
{{- dig "password" "password" $b -}}
{{- end }}

{{- define "groundx.admin.username" -}}
{{- $b := .Values.admin | default dict -}}
{{- dig "username" "00000000-0000-0000-0000-000000000000" $b -}}
{{- end }}

{{- define "groundx.clusterType" -}}
{{- $b := .Values.cluster | default dict -}}
{{- dig "type" "eks" $b -}}
{{- end }}

{{- define "groundx.ingestOnly" -}}
{{ .Values.ingestOnly | default false }}
{{- end }}

{{- define "groundx.isOpenshift" -}}
{{- $t := include "groundx.clusterType" . -}}
{{- eq $t "openshift" -}}
{{- end }}

{{- define "groundx.createSymlink" -}}
{{- $t := include "groundx.clusterType" . -}}
{{- and (ne $t "openshift") (ne $t "minikube") -}}
{{- end }}

{{- define "groundx.environment" -}}
{{ .Values.environment | default "prod" }}
{{- end }}

{{- define "groundx.hasMig" -}}
{{- $b := .Values.cluster | default dict -}}
{{- dig "hasMig" false $b -}}
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

{{- define "groundx.languages" -}}
{{ .Values.languages | default (list "en") }}
{{- end }}

{{- define "groundx.logLevel" -}}
{{ .Values.logLevel | default "warn" }}
{{- end }}

{{- define "groundx.busybox.image" -}}
{{- printf "%s/eyelevel/busybox:latest" (include "groundx.imageRepository" .) -}}
{{- end }}

{{- define "groundx.busybox.pull" -}}
Always
{{- end }}

{{- define "groundx.node.cpuMemory" -}}
{{- $b := .Values.cluster | default dict -}}
{{- $in := dig "nodeLabels" dict $b -}}
{{ dig "cpuMemory" "eyelevel-cpu-memory" $in }}
{{- end }}

{{- define "groundx.node.cpuOnly" -}}
{{- $b := .Values.cluster | default dict -}}
{{- $in := dig "nodeLabels" dict $b -}}
{{ dig "cpuOnly" "eyelevel-cpu-only" $in }}
{{- end }}

{{- define "groundx.node.gpuLayout" -}}
{{- $b := .Values.cluster | default dict -}}
{{- $in := dig "nodeLabels" dict $b -}}
{{ dig "gpuLayout" "eyelevel-gpu-layout" $in }}
{{- end }}

{{- define "groundx.node.gpuRanker" -}}
{{- $b := .Values.cluster | default dict -}}
{{- $in := dig "nodeLabels" dict $b -}}
{{ dig "gpuRanker" "eyelevel-gpu-ranker" $in }}
{{- end }}

{{- define "groundx.node.gpuSummary" -}}
{{- $b := .Values.cluster | default dict -}}
{{- $in := dig "nodeLabels" dict $b -}}
{{ dig "gpuSummary" "eyelevel-gpu-summary" $in }}
{{- end }}

{{- define "groundx.pvClass" -}}
{{- $b := .Values.cluster | default dict -}}
{{- dig "pvClass" "eyelevel-pv" $b -}}
{{- end }}
