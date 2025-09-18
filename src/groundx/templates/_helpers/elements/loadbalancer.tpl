{{- define "groundx.renderLoadBalancer" -}}
{{- $lb := .lb | fromYaml -}}
{{- $name := .name -}}
{{- $root := .root -}}
{{- $hasInternal := and (eq (dig "isInternal" "" $lb) "true") (eq (dig "type" "" $lb) "LoadBalancer") -}}
{{- $hasTO := and (hasKey $lb "timeout") (not (empty (dig "timeout" "" $lb))) -}}

---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name | quote }}
  namespace: {{ include "groundx.ns" $root | quote }}
  labels:
    app: {{ $name | quote }}
{{- if or $hasInternal $hasTO }}
  annotations:
{{- if $hasTO }}
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: {{ (dig "timeout" "" $lb) | quote }}
{{- end }}
{{- if $hasInternal }}
    service.beta.kubernetes.io/aws-load-balancer-internal: {{ (dig "isInternal" "true" $lb) | quote }}
{{- end }}
{{- end }}
spec:
  selector:
    app: {{ $name }}
  ports:
    - protocol: TCP
      port: {{ dig "port" 8080 $lb }}
      targetPort: {{ dig "targetPort" 8080 $lb }}
  type: {{ dig "type" "ClusterIP" $lb }}

{{- end }}
