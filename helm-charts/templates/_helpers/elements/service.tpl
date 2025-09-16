{{- define "groundx.renderService" -}}
{{- $name := .name -}}
{{- $port := .port -}}
{{- $root := .root -}}
{{- $type := .type -}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: "{{ $name }}-sa-rolebinding"
subjects:
- kind: ServiceAccount
  name: "{{ $name }}-sa"
  namespace: {{ include "groundx.ns" $root | quote }}
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name | quote }}
  namespace: {{ include "groundx.ns" $root | quote }}
  labels:
    app: {{ $name | quote }}
spec:
  ports:
    - protocol: TCP
      port: {{ $port }}
      targetPort: {{ $port }}
  selector:
    app: {{ $name | quote }}
  type: {{ $type | quote }}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "{{ $name }}-sa"
{{- end }}
