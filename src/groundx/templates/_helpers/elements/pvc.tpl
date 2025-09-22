{{- define "groundx.renderPVC" -}}
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
    app: {{ $name | quote }}
spec:
  storageClassName: {{ dig "class" "" $pvc }}
  accessModes:
    - {{ dig "access" "" $pvc }}
  resources:
    requests:
      storage: {{ dig "capacity" "" $pvc }}

{{- end }}
