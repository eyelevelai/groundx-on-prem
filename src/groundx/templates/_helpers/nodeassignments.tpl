{{- define "groundx.cluster.assignment.defaults" -}}
{{- dict
  "cache"             "cpuOnly"
  "cache-metrics"     "cpuOnly"
  "db"                "cpuOnly"
  "db-cluster"        "cpuOnly"
  "file"              "cpuOnly"
  "graph"             "cpuOnly"
  "groundx"           "cpuOnly"
  "file-tenant"       "cpuOnly"
  "layout-api"        "cpuOnly"
  "layout-correct"    "cpuMemory"
  "layout-inference"  "gpuLayout"
  "layout-map"        "cpuOnly"
  "layout-ocr"        "cpuMemory"
  "layout-process"    "cpuMemory"
  "layout-save"       "cpuMemory"
  "layout-webhook"    "cpuOnly"
  "metrics"           "cpuOnly"
  "pre-process"       "cpuMemory"
  "process"           "cpuOnly"
  "queue"             "cpuOnly"
  "ranker-api"        "cpuOnly"
  "ranker-inference"  "gpuRanker"
  "summary-api"       "cpuOnly"
  "summary-inference" "gpuSummary"
  "summary-client"    "cpuOnly"
  "search"            "cpuOnly"
  "stream"            "cpuOnly"
  "stream-cluster"    "cpuOnly"
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
