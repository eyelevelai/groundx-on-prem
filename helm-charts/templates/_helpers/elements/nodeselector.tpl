{{- define "groundx.renderNodeSelector" -}}
{{- $name := .name -}}
{{- $indent := .indent | default 0 -}}
{{- $root := .root -}}
{{ printf "%*s" $indent "" }}nodeSelector:
{{ printf "%*s" (add $indent 2) "" }}node: {{ include "groundx.node.value" (dict "name" $name "root" $root) | quote }}
{{ printf "%*s" $indent "" }}tolerations:
{{ printf "%*s" (add $indent 2) "" }}- key: "node"
{{ printf "%*s" (add $indent 4) "" }}value: {{ include "groundx.node.value" (dict "name" $name "root" $root) | quote }}
{{ printf "%*s" (add $indent 4) "" }}effect: "NoSchedule"
{{- end }}