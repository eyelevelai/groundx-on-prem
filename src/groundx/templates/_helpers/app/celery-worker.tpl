{{- define "groundx.celeryWorker.defaultGrace" -}}
{{- if eq . "summary.inference" -}}300{{- else -}}900{{- end -}}
{{- end }}

{{- define "groundx.celeryWorker.gracePeriod" -}}
{{- $default := int (include "groundx.celeryWorker.defaultGrace" .key) -}}
{{- int (dig "gracePeriod" $default (.replicas | default dict)) -}}
{{- end }}

{{- define "groundx.celeryWorker.stopWaitSecs" -}}
{{- $grace := int (include "groundx.celeryWorker.gracePeriod" .) -}}
{{- int (max 1 (sub $grace 30)) -}}
{{- end }}

{{- define "groundx.celeryWorker.group" -}}
[group:celery_workers]
    programs={{ range $i, $_ := until (int .) }}{{ if $i }},{{ end }}celery_worker_{{ add $i 1 }}{{ end }}
{{- end }}

{{- define "groundx.celeryWorker.command" -}}
{{- if .inheritPath -}}
export PYTHONPATH={{ .workDir }}:$PYTHONPATH && exec supervisord -c {{ .workDir }}/supervisord.conf
{{- else -}}
export PYTHONPATH={{ .workDir }} && exec supervisord -c {{ .workDir }}/supervisord.conf
{{- end -}}
{{- end }}

{{- define "groundx.celeryWorker.initContainer" -}}
{{- $root := .root -}}
{{- $image := .image -}}
{{- $pull := .pull -}}
{{- $scr := .secrets -}}
{{- $wd := .workDir -}}
{{- $initCmd := .initCommand -}}
{{- $csct := .containerSecurityContext -}}
{{- $username := .username -}}
{{- $rs := .resources -}}
{{- $pvc := .pvc -}}
- name: init-layout
          image: {{ $image | quote }}
          imagePullPolicy: {{ $pull | quote }}
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
{{- with include "groundx.fileAccess.caEnv" $root }}
{{ . | nindent 12 }}
{{- end }}
{{- if gt (len $scr) 0 }}
          envFrom:
{{- range $kk, $vv := $scr }}
            - secretRef:
                name: {{ $vv }}
{{- end }}
{{- end }}
          workingDir: {{ $wd }}
          command:
            - /bin/sh
            - -c
            - |
              export PYTHONPATH={{ $wd }}:$PYTHONPATH && exec {{ $initCmd | replace "/app" $wd }}
{{ include "groundx.renderSecurityContext" (dict "ctx" $csct "indent" 10 "root" $root "user" $username "cfg" "container") }}
{{ include "groundx.renderContainerResources" (dict "ctx" $rs "indent" 10) }}
          volumeMounts:
{{- with include "groundx.fileAccess.caMount" $root }}
{{ . | nindent 12 }}
{{- end }}
            - name: config-models
              mountPath: {{ $wd }}/config_models.py
              subPath: config_models.py
            - name: config-volume
              mountPath: {{ $wd }}/config.py
              subPath: config.py
{{- if not (empty $pvc) }}
            - name: model-volume
              mountPath: {{ $wd }}/hf_models_cache
{{- end }}
{{- end }}
