{{- define "groundx.renderPVC" -}}
{{- $app := .app -}}
{{- $pvc := .ctx -}}
{{- $root := .root -}}
{{- $name := dig "name" "" $pvc -}}

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ $name | quote }}
  namespace: {{ include "groundx.ns" $root | quote }}
  labels:
    app: {{ $app | quote }}
spec:
  storageClassName: {{ dig "class" "" $pvc }}
  accessModes:
    - {{ dig "access" "" $pvc }}
  resources:
    requests:
      storage: {{ dig "capacity" "" $pvc }}

{{- end }}
