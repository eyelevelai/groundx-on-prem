{{- define "groundx.workspace.values" -}}
{{- .Values.workspace | default dict | toYaml -}}
{{- end }}

{{- define "groundx.workspace.serviceName" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "serviceName" "workspace" $in }}
{{- end }}

{{- define "groundx.workspace.create" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{- if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}
    {{- if and (eq (dig "token" "" $in) "") (eq (dig "existingSecret" "" $in) "") -}}
      {{- fail "workspace requires workspace.token or workspace.existingSecret when enabled" -}}
    {{- end -}}
true
  {{- else -}}false{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.workspace.node" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ coalesce (dig "node" "" $in) (include "groundx.node.cpuOnly" .) }}
{{- end }}

{{- define "groundx.workspace.allowedCommands" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "allowedCommands" "go,npm,pytest,python,node,git" $in }}
{{- end }}

{{- define "groundx.workspace.celeryBrokerUrl" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{- $fallback := printf "%s://%s:%v/0" (include "groundx.cache.scheme" .) (include "groundx.cache.addr" .) (include "groundx.cache.port" .) -}}
{{ coalesce (dig "celeryBrokerUrl" "" $in) $fallback }}
{{- end }}

{{- define "groundx.workspace.celeryGlobalKeyprefix" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "celeryGlobalKeyprefix" "{workspace}" $in }}
{{- end }}

{{- define "groundx.workspace.celeryResultBackend" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{- $fallback := printf "%s://%s:%v/0" (include "groundx.cache.scheme" .) (include "groundx.cache.addr" .) (include "groundx.cache.port" .) -}}
{{ coalesce (dig "celeryResultBackend" "" $in) $fallback }}
{{- end }}

{{- define "groundx.workspace.celerySoftTimeLimitSeconds" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "celerySoftTimeLimitSeconds" 900 $in }}
{{- end }}

{{- define "groundx.workspace.celeryTaskAlwaysEager" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "celeryTaskAlwaysEager" false $in }}
{{- end }}

{{- define "groundx.workspace.commandTimeoutSeconds" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "commandTimeoutSeconds" 300 $in }}
{{- end }}

{{- define "groundx.workspace.mysqlConnectTimeoutSeconds" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "mysqlConnectTimeoutSeconds" 10 $in }}
{{- end }}

{{- define "groundx.workspace.publishDryRun" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "publishDryRun" true $in }}
{{- end }}

{{- define "groundx.workspace.publishGithubWorkflowId" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "publishGithubWorkflowId" "deploy.yml" $in }}
{{- end }}

{{- define "groundx.workspace.github" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "github" dict $in | toYaml }}
{{- end }}

{{- define "groundx.workspace.gitProvider" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "gitProvider" "github" $in }}
{{- end }}

{{- define "groundx.workspace.github.apiBaseUrl" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{ dig "apiBaseUrl" "https://api.github.com" $g }}
{{- end }}

{{- define "groundx.workspace.github.appId" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{ dig "appId" "" $g }}
{{- end }}

{{- define "groundx.workspace.github.installationId" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{ dig "installationId" "" $g }}
{{- end }}

{{- define "groundx.workspace.github.privateKeyPem" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{ dig "privateKeyPem" "" $g }}
{{- end }}

{{- define "groundx.workspace.github.privateKeySecretName" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{- $s := dig "privateKeySecret" dict $g -}}
{{ dig "name" "" $s }}
{{- end }}

{{- define "groundx.workspace.github.privateKeySecretKey" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{- $s := dig "privateKeySecret" dict $g -}}
{{ dig "key" "private-key.pem" $s }}
{{- end }}

{{- define "groundx.workspace.github.privateKeyPath" -}}
{{- if ne (include "groundx.workspace.github.privateKeySecretName" .) "" -}}
/var/run/secrets/workspace/github/private-key.pem
{{- else -}}
{{- "" -}}
{{- end }}
{{- end }}

{{- define "groundx.workspace.github.tokenTtlSeconds" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{ dig "tokenTtlSeconds" 3600 $g }}
{{- end }}

{{- define "groundx.workspace.gitlab" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "gitlab" dict $in | toYaml }}
{{- end }}

{{- define "groundx.workspace.gitlab.apiBaseUrl" -}}
{{- $g := include "groundx.workspace.gitlab" . | fromYaml -}}
{{ dig "apiBaseUrl" "https://gitlab.com/api/v4" $g }}
{{- end }}

{{- define "groundx.workspace.gitlab.token" -}}
{{- $g := include "groundx.workspace.gitlab" . | fromYaml -}}
{{ dig "token" "" $g }}
{{- end }}

{{- define "groundx.workspace.gitlab.tokenSecretName" -}}
{{- $g := include "groundx.workspace.gitlab" . | fromYaml -}}
{{- $s := dig "tokenSecret" dict $g -}}
{{ dig "name" "" $s }}
{{- end }}

{{- define "groundx.workspace.gitlab.tokenSecretKey" -}}
{{- $g := include "groundx.workspace.gitlab" . | fromYaml -}}
{{- $s := dig "tokenSecret" dict $g -}}
{{ dig "key" "token" $s }}
{{- end }}

{{- define "groundx.workspace.gitlab.tokenPath" -}}
{{- if ne (include "groundx.workspace.gitlab.tokenSecretName" .) "" -}}
/var/run/secrets/workspace/gitlab/token
{{- else -}}
{{- "" -}}
{{- end }}
{{- end }}

{{- define "groundx.workspace.managedRepoNamePrefix" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "managedRepoNamePrefix" "workspace" $in }}
{{- end }}

{{- define "groundx.workspace.managedRepoOwner" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "managedRepoOwner" "" $in }}
{{- end }}

{{- define "groundx.workspace.managedRepoVisibility" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "managedRepoVisibility" "private" $in }}
{{- end }}

{{- define "groundx.workspace.token" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "token" "" $in }}
{{- end }}

{{- define "groundx.workspace.existingSecret" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "existingSecret" "" $in }}
{{- end }}

{{- define "groundx.workspace.secretName" -}}
{{- $existing := include "groundx.workspace.existingSecret" . -}}
{{- if ne $existing "" -}}
{{ $existing }}
{{- else -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ coalesce (dig "secretName" "" $in) (printf "%s-secret" (include "groundx.workspace.serviceName" .)) }}
{{- end -}}
{{- end }}

{{- define "groundx.workspace.githubSecretName" -}}
{{- $g := include "groundx.workspace.github" . | fromYaml -}}
{{ coalesce (dig "secretName" "" $g) (printf "%s-github-secret" (include "groundx.workspace.serviceName" .)) }}
{{- end }}

{{- define "groundx.workspace.gitlabSecretName" -}}
{{- $g := include "groundx.workspace.gitlab" . | fromYaml -}}
{{ coalesce (dig "secretName" "" $g) (printf "%s-gitlab-secret" (include "groundx.workspace.serviceName" .)) }}
{{- end }}

{{- define "groundx.workspace.secrets" -}}
{{- $token := include "groundx.workspace.token" . -}}
{{- $cfg := dict "name" (include "groundx.workspace.secretName" .) -}}
{{- if ne $token "" -}}
{{- $_ := set $cfg "data" (dict "WORKSPACE_RUNNER_TOKEN" $token) -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.workspace.github.secrets" -}}
{{- $privateKeyPem := include "groundx.workspace.github.privateKeyPem" . -}}
{{- $cfg := dict "name" (include "groundx.workspace.githubSecretName" .) -}}
{{- if ne $privateKeyPem "" -}}
{{- $_ := set $cfg "data" (dict "GITHUB_APP_PRIVATE_KEY_PEM" $privateKeyPem) -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.workspace.gitlab.secrets" -}}
{{- $token := include "groundx.workspace.gitlab.token" . -}}
{{- $cfg := dict "name" (include "groundx.workspace.gitlabSecretName" .) -}}
{{- if ne $token "" -}}
{{- $_ := set $cfg "data" (dict "GITLAB_TOKEN" $token) -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.workspace.workspaceRoot" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "workspaceRoot" "/tmp/workspaces" $in }}
{{- end }}

{{- define "groundx.workspace.workspaceMinFreeBytes" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "workspaceMinFreeBytes" 0 $in }}
{{- end }}

{{- define "groundx.workspace.workspaceMinFreePercent" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "workspaceMinFreePercent" 0 $in }}
{{- end }}

{{- define "groundx.workspace.workspaceVolumeName" -}}
workspace-data
{{- end }}

{{- define "groundx.workspace.pvc" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{- $pvc := omit (dig "pvc" dict $in) "enabled" -}}
{{- $defaults := dict
  "access" (include "groundx.pvAccessMode" .)
  "capacity" "20Gi"
  "class" (include "groundx.pvClass" .)
  "name" (printf "%s-data" (include "groundx.workspace.serviceName" .))
-}}
{{ mergeOverwrite $defaults $pvc | toYaml }}
{{- end }}

{{- define "groundx.workspace.workspaceVolume" -}}
{{- $pvc := include "groundx.workspace.pvc" . | fromYaml -}}
- name: {{ include "groundx.workspace.workspaceVolumeName" . }}
  persistentVolumeClaim:
    claimName: {{ get $pvc "name" }}
{{- end }}

{{- define "groundx.workspace.workspaceVolumeMount" -}}
- name: {{ include "groundx.workspace.workspaceVolumeName" . }}
  mountPath: {{ include "groundx.workspace.workspaceRoot" . }}
{{- end }}

{{- define "groundx.workspace.githubPrivateKeyVolumeName" -}}
workspace-github-private-key
{{- end }}

{{- define "groundx.workspace.githubPrivateKeyVolume" -}}
{{- $secretName := include "groundx.workspace.github.privateKeySecretName" . -}}
{{- if ne $secretName "" -}}
- name: {{ include "groundx.workspace.githubPrivateKeyVolumeName" . }}
  secret:
    secretName: {{ $secretName }}
    items:
      - key: {{ include "groundx.workspace.github.privateKeySecretKey" . }}
        path: private-key.pem
{{- end }}
{{- end }}

{{- define "groundx.workspace.githubPrivateKeyVolumeMount" -}}
{{- if ne (include "groundx.workspace.github.privateKeySecretName" .) "" -}}
- name: {{ include "groundx.workspace.githubPrivateKeyVolumeName" . }}
  mountPath: /var/run/secrets/workspace/github
  readOnly: true
{{- end }}
{{- end }}

{{- define "groundx.workspace.gitlabTokenVolumeName" -}}
workspace-gitlab-token
{{- end }}

{{- define "groundx.workspace.gitlabTokenVolume" -}}
{{- $secretName := include "groundx.workspace.gitlab.tokenSecretName" . -}}
{{- if ne $secretName "" -}}
- name: {{ include "groundx.workspace.gitlabTokenVolumeName" . }}
  secret:
    secretName: {{ $secretName }}
    items:
      - key: {{ include "groundx.workspace.gitlab.tokenSecretKey" . }}
        path: token
{{- end }}
{{- end }}

{{- define "groundx.workspace.gitlabTokenVolumeMount" -}}
{{- if ne (include "groundx.workspace.gitlab.tokenSecretName" .) "" -}}
- name: {{ include "groundx.workspace.gitlabTokenVolumeName" . }}
  mountPath: /var/run/secrets/workspace/gitlab
  readOnly: true
{{- end }}
{{- end }}

{{- define "groundx.workspace.volumeMounts" -}}
{{ include "groundx.workspace.workspaceVolumeMount" . }}
{{ include "groundx.workspace.githubPrivateKeyVolumeMount" . }}
{{ include "groundx.workspace.gitlabTokenVolumeMount" . }}
{{- end }}

{{- define "groundx.workspace.volumes" -}}
{{ include "groundx.workspace.workspaceVolume" . }}
{{ include "groundx.workspace.githubPrivateKeyVolume" . }}
{{ include "groundx.workspace.gitlabTokenVolume" . }}
{{- end }}

{{- define "groundx.workspace.services" -}}
{{- $services := list -}}
{{- if eq (include "groundx.workspace.provision.create" .) "true" -}}{{- $services = append $services "workspace.provision" -}}{{- end -}}
{{- if eq (include "groundx.workspace.workspace.create" .) "true" -}}{{- $services = append $services "workspace.workspace" -}}{{- end -}}
{{- if eq (include "groundx.workspace.command.create" .) "true" -}}{{- $services = append $services "workspace.command" -}}{{- end -}}
{{- if eq (include "groundx.workspace.publish.create" .) "true" -}}{{- $services = append $services "workspace.publish" -}}{{- end -}}
{{- if eq (include "groundx.workspace.cleanup.create" .) "true" -}}{{- $services = append $services "workspace.cleanup" -}}{{- end -}}
{{- $services | toYaml -}}
{{- end }}
