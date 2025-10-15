{{- define "groundx.ns" -}}
{{ .Values.namespace | default "eyelevel" }}
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
{{- (dig "type" "eks" $b) | lower -}}
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

{{- define "groundx.imagePull" -}}
{{- $b := .Values.cluster | default dict -}}
{{- dig "imagePull" "IfNotPresent" $b -}}
{{- end }}

{{- define "groundx.languages" -}}
{{ .Values.languages | default (list "en") }}
{{- end }}

{{- define "groundx.logLevel" -}}
{{ .Values.logLevel | default "info" }}
{{- end }}

{{- define "groundx.busybox.image" -}}
{{- $in := .Values.busybox | default dict -}}
{{- $repoPrefix := include "groundx.imageRepository" . | trim -}}
{{- $ver := coalesce .Chart.AppVersion .Chart.Version -}}
{{- $fallback := printf "%s/eyelevel/busybox:1.0.0" $repoPrefix -}}
{{- coalesce (dig "image" "" $in) $fallback -}}
{{- end }}

{{- define "groundx.busybox.pull" -}}
{{- $in := .Values.busybox | default dict -}}
{{ dig "imagePullPolicy" (include "groundx.imagePull" .) $in }}
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

{{- define "groundx.preProcessors" -}}
{{- $in := .Values.cluster | default dict -}}
{{- $pres := dig "preProcessors" list $in -}}
{{- if gt (len $pres) 0 }}
extraPreDefaults:
{{- range $pres }}
  - processorID: {{ .processorId }}
    type: {{ .type }}
{{- end }}
{{- end }}
{{- end }}

{{- define "groundx.pvClass" -}}
{{- $b := .Values.cluster | default dict -}}
{{- dig "pvClass" "eyelevel-pv" $b -}}
{{- end }}

{{- define "groundx.validApiKeys" -}}
{{- $b := .Values.cluster | default dict -}}
{{- dig "validApiKeys" list $b -}}
{{- end }}
