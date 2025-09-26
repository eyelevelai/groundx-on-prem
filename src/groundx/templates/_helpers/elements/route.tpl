{{- define "groundx.renderRoute" -}}
{{- $lb := .lb | fromYaml -}}
{{- $name := .name -}}
{{- $root := .root -}}
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: {{ $name | quote }}
  namespace: {{ include "groundx.ns" $root | quote }}
  labels:
    app: {{ $name | quote }}
spec:
  to:
    kind: Service
    name: {{ $name | quote }}
  port:
    port: {{ (dig "port" 8080 $lb) }}
    targetPort: {{ (dig "targetPort" 8080 $lb) }}
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: edge
{{- end }}
