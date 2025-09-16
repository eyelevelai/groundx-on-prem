{{- define "groundx.cluster.assignment.defaults" -}}
{{- dict
  "cache"             "cpuOnly"
  "cache-metrics"     "cpuOnly"
  "db"                "cpuOnly"
  "db-cluster"        "cpuOnly"
  "file"              "cpuOnly"
  "graph"             "cpuOnly"
  "file-tenant"       "cpuOnly"
  "layout_api"        "cpuOnly"
  "layout_correct"    "cpuMemory"
  "layout_inference"  "gpuLayout"
  "layout_map"        "cpuOnly"
  "layout_ocr"        "cpuMemory"
  "layout_process"    "cpuMemory"
  "layout_save"       "cpuMemory"
  "layout_webhook"    "cpuOnly"
  "metrics"           "cpuOnly"
  "pre_process"       "cpuMemory"
  "process"           "cpuOnly"
  "queue"             "cpuOnly"
  "ranker_api"        "cpuOnly"
  "ranker_inference"  "gpuRanker"
  "summary_api"       "cpuOnly"
  "summary_inference" "gpuSummary"
  "summary_client"    "cpuOnly"
  "search"            "cpuOnly"
  "stream"            "cpuOnly"
  "upload"            "cpuOnly"
  | toYaml -}}
{{- end }}

{{- define "groundx.cluster.nodes.defaults" -}}
{{- dict
  "cpuOnly"    (dict "node" (default "eyelevel-cpu-only" .Values.cluster.nodeLabels.cpuOnly))
  "cpuMemory"  (dict "node" (default "eyelevel-cpu-memory" .Values.cluster.nodeLabels.cpuMemory))
  "gpuLayout"  (dict "node" (default "eyelevel-gpu-layout" .Values.cluster.nodeLabels.gpuLayout))
  "gpuRanker"  (dict "node" (default "eyelevel-gpu-ranker" .Values.cluster.nodeLabels.gpuRanker))
  "gpuSummary" (dict "node" (default "eyelevel-gpu-summary" .Values.cluster.nodeLabels.gpuSummary))
  | toYaml -}}
{{- end }}

{{- define "groundx.node.value" -}}
{{- $name := .name -}}
{{- $root := .root | default $ -}}
{{- $assign := include "groundx.cluster.assignment.defaults" $root | fromYaml -}}
{{- $class := get $assign $name | default "cpuOnly" -}}
{{- $nodes := include "groundx.cluster.nodes.defaults" $root | fromYaml -}}
{{- $cfg := get $nodes $class | default dict -}}
{{- $cfg.node | default "" -}}
{{- end }}
