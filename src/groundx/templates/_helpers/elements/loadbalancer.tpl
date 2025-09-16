{{- define "groundx.renderLoadBalancer" -}}
{{- $lb := .lb | fromYaml -}}
{{- $name := .name -}}
{{- $root := .root -}}
{{- $hasInternal := and (hasKey $lb "isInternal") (not (empty (dig "isInternal" "" $lb))) -}}
{{- $hasTO := and (hasKey $lb "timeout") (not (empty (dig "timeout" "" $lb))) -}}
---
apiVersion: v1
kind: Service
metadata:
  name: "{{ $name }}-service"
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
      port: {{ (dig "port" 8080 $lb) }}
      targetPort: {{ (dig "targetPort" 8080 $lb) }}
  type: LoadBalancer
{{- end }}
