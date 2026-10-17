{{- define "groundx.fileAccess.create" -}}
{{- if dig "enabled" false (.Values.fileAccess | default dict) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "groundx.fileAccess.validate" -}}
{{- if eq (include "groundx.fileAccess.create" .) "true" -}}
{{- $in := .Values.fileAccess -}}
{{- if not $in.originsPrivate -}}
{{- fail "fileAccess.originsPrivate must be true after operator verification of all storage aliases" -}}
{{- end -}}
{{- if not $in.frontProxyTLSVerified -}}
{{- fail "fileAccess.frontProxyTLSVerified must be true after operator verification of HTTPS termination and encrypted trusted gateway backplane" -}}
{{- end -}}
{{- range $key := list "username" "password" "token" -}}
  {{- if not (empty (get $.Values.file $key)) -}}
    {{- fail (printf "file.%s is ignored when fileAccess is enabled; remove it and use fileAccess.storageCredentialsSecretName or native S3 ambient credentials" $key) -}}
  {{- end -}}
{{- end -}}
{{- if eq (include "groundx.extract.create" .) "true" -}}
  {{- $extractFile := dig "file" dict (.Values.extract | default dict) -}}
  {{- range $key := list "username" "password" -}}
    {{- if not (empty (get $extractFile $key)) -}}
      {{- fail (printf "extract.file.%s is ignored when fileAccess is enabled; remove it and use fileAccess.storageCredentialsSecretName or native S3 ambient credentials" $key) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $publicURL := required "fileAccess.publicUrl is required" $in.publicUrl -}}
{{- if contains "@" $publicURL -}}
  {{- fail "fileAccess.publicUrl must not contain credentials" -}}
{{- end -}}
{{- $public := urlParse $publicURL -}}
{{- if and (ne $public.path "") (ne $public.path "/") -}}
  {{- fail "fileAccess.publicUrl must be the stable file host root without a bucket path" -}}
{{- end -}}
{{- $presentationDomain := include "groundx.file.domain" . -}}
{{- if contains "@" $presentationDomain -}}
  {{- fail "file presentation host must not contain credentials when fileAccess is enabled" -}}
{{- end -}}
{{- $presentation := urlParse (printf "http://%s" $presentationDomain) -}}
{{- if ne (lower $presentation.host) (lower $public.host) -}}
  {{- fail "fileAccess.publicUrl host must match the existing file presentation host" -}}
{{- end -}}
{{- if and (eq (include "groundx.extract.create" .) "true") (ne (include "groundx.extract.file.bucketName" .) (include "groundx.file.bucketName" .)) -}}
  {{- fail "extract.file.bucketName must match file.bucketName when fileAccess is enabled" -}}
{{- end -}}
{{- $extractURL := dig "file" "url" "" (.Values.extract | default dict) -}}
{{- if and (eq (include "groundx.extract.create" .) "true") (not (empty $extractURL)) -}}
  {{- if contains "@" $extractURL -}}
    {{- fail "extract.file.url must not contain credentials when fileAccess is enabled" -}}
  {{- end -}}
  {{- if ne (lower (urlParse $extractURL).host) (lower $public.host) -}}
    {{- fail "extract.file.url host must match fileAccess.publicUrl when the gateway is enabled" -}}
  {{- end -}}
{{- end -}}
{{- $ingressHost := "" -}}
{{- if dig "enabled" false $in.ingress -}}
  {{- $ingressHost = lower (tpl (dig "hostName" "" $in.ingress) .) -}}
{{- end -}}
{{- $nativeIngress := include "groundx.file.ingress" . | fromYaml | default dict -}}
{{- if dig "enabled" false $nativeIngress -}}
  {{- $nativeHost := lower (tpl (dig "data" "hostName" "" $nativeIngress) .) -}}
  {{- if or (eq $nativeHost (lower $public.hostname)) (and (not (empty $ingressHost)) (eq $nativeHost $ingressHost)) -}}
    {{- fail "file.ingress host must not use a fileAccess delivery host" -}}
  {{- end -}}
{{- end -}}
{{- range $key := list "publicUrl" "storageEndpoint" "signingEndpoint" -}}
  {{- $raw := required (printf "fileAccess.%s is required" $key) (get $in $key) -}}
  {{- if contains "@" $raw -}}
    {{- fail (printf "fileAccess.%s must not contain credentials" $key) -}}
  {{- end -}}
  {{- $url := urlParse $raw -}}
  {{- if or (ne $url.scheme "https") (empty $url.host) (not (empty $url.userinfo)) (not (empty $url.query)) (not (empty $url.fragment)) -}}
    {{- fail (printf "fileAccess.%s must be an HTTPS URL without credentials, query or fragment" $key) -}}
  {{- end -}}
  {{- if ne $key "publicUrl" -}}
    {{- if or (eq (lower $url.hostname) (lower $public.hostname)) (and (not (empty $ingressHost)) (eq (lower $url.hostname) $ingressHost)) -}}
      {{- fail (printf "fileAccess.%s must not use the delivery host" $key) -}}
    {{- end -}}
    {{- if ne $url.path "" -}}
      {{- fail (printf "fileAccess.%s must name the S3 API endpoint without a path or trailing slash" $key) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $alias := dig "trustedOrigins" list $in -}}
  {{- if contains "@" $alias -}}
    {{- fail "fileAccess.trustedOrigins must not contain credentials" -}}
  {{- end -}}
  {{- $url := urlParse $alias -}}
  {{- if or (ne $url.scheme "https") (empty $url.host) (not (empty $url.userinfo)) (not (empty $url.query)) (not (empty $url.fragment)) (and (ne $url.path "") (ne $url.path "/")) -}}
    {{- fail "fileAccess.trustedOrigins entries must be HTTPS origins without credentials, query, fragment or nonroot path" -}}
  {{- end -}}
{{- end -}}
{{- if ne (include "groundx.file.storageType" .) "s3" -}}
  {{- $_ := required "fileAccess.storageCredentialsSecretName is required" $in.storageCredentialsSecretName -}}
{{- end -}}
{{- if dig "enabled" false $in.ingress -}}
  {{- $_ := required "fileAccess.tlsSecretName is required for ingress" $in.tlsSecretName -}}
  {{- range $key, $value := dig "annotations" dict $in.ingress -}}
    {{- if regexMatch "(?i)(rewrite|cache|snippet|auth-|upstream-vhost)" $key -}}
      {{- fail (printf "fileAccess.ingress annotation %s can change file authorization, paths or response freshness" $key) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "groundx.fileAccess.serviceName" -}}
{{ dig "serviceName" "file-access" (.Values.fileAccess | default dict) }}
{{- end }}

{{- define "groundx.fileAccess.port" -}}
{{ dig "containerPort" 8080 (.Values.fileAccess | default dict) }}
{{- end }}

{{- define "groundx.fileAccess.settings" -}}
{{- include "groundx.fileAccess.validate" . -}}
{{- $in := .Values.fileAccess -}}
{{- $image := dig "image" dict $in -}}
{{- $cfg := dict
  "dependencies" (dict "cache" "cache" "db" "db")
  "image" (printf "%s/eyelevel/%s:%s" (dig "repository" (include "groundx.imageRepository" .) $image) (dig "name" "file-access" $image) (dig "tag" (coalesce .Chart.AppVersion .Chart.Version) $image))
  "name" (include "groundx.fileAccess.serviceName" .)
  "node" (dig "node" (include "groundx.node.cpuOnly" .) $in)
  "port" (include "groundx.fileAccess.port" .)
  "pull" (dig "imagePullPolicy" (include "groundx.imagePullPolicy" .) $in)
  "replicas" (dict "desired" $in.replicas)
  "probe" (dict "readiness" (dict "path" "/readyz"))
  "interface" (dict "type" "ClusterIP" "port" (include "groundx.fileAccess.port" .) "targetPort" (include "groundx.fileAccess.port" .) | toYaml)
-}}
{{- $sa := dig "serviceAccount" dict $in -}}
{{- $saCreate := dig "create" false $sa -}}
{{- $saDefault := include "groundx.serviceAccountName" . -}}
{{- if $saCreate -}}{{- $saDefault = include "groundx.fileAccess.serviceName" . -}}{{- end -}}
{{- $san := dig "name" $saDefault $sa -}}
{{- if $saCreate -}}
  {{- $_ := required "fileAccess.serviceAccount.name must not be empty when create is true" $san -}}
  {{- $_ := set $cfg "createServiceAccount" true -}}
  {{- $_ := set $cfg "serviceAccountAnnotations" (dig "annotations" dict $sa) -}}
{{- end -}}
{{- if $san -}}{{- $_ := set $cfg "serviceAccountName" $san -}}{{- end -}}
{{- range $key := list "affinity" "annotations" "containerSecurityContext" "labels" "nodeSelector" "resources" "securityContext" "tolerations" "topologySpreadConstraints" "disruptionBudget" -}}
  {{- if hasKey $in $key -}}{{- $_ := set $cfg $key (get $in $key) -}}{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.fileAccess.config" -}}
{{- include "groundx.fileAccess.validate" . -}}
{{- $in := .Values.fileAccess -}}
fileAccess:
  enabled: true
  frontProxyTLSVerified: {{ $in.frontProxyTLSVerified }}
  publicUrl: {{ $in.publicUrl | quote }}
  {{- with $in.trustedOrigins }}
  trustedOrigins:
{{ toYaml . | indent 4 }}
  {{- end }}
  originsPrivate: {{ $in.originsPrivate }}
  policyCacheTtlSeconds: {{ $in.policyCacheTtlSeconds }}
  mappingCacheTtlSeconds: {{ $in.mappingCacheTtlSeconds }}
  lookupTimeout: {{ $in.lookupTimeout | quote }}
  maxLookupConcurrency: {{ $in.maxLookupConcurrency }}
  maxPresentationBytes: {{ $in.maxPresentationBytes }}
  maxConcurrentPresentations: {{ $in.maxConcurrentPresentations }}
fileAccessServer:
  port: {{ include "groundx.fileAccess.port" . }}
  serviceName: {{ include "groundx.fileAccess.serviceName" . }}
{{- end }}

{{- define "groundx.fileAccess.ingress" -}}
{{- include "groundx.fileAccess.validate" . -}}
{{- $in := .Values.fileAccess | default dict -}}
{{- if and (eq (include "groundx.fileAccess.create" .) "true") (dig "ingress" "enabled" false $in) -}}
{{- $public := urlParse $in.publicUrl -}}
{{- $host := coalesce (dig "ingress" "hostName" "" $in) $public.hostname -}}
{{- $anns := deepCopy (dig "ingress" "annotations" dict $in) -}}
{{- $_ := set $anns "nginx.ingress.kubernetes.io/ssl-redirect" "true" -}}
{{- $_ := set $anns "nginx.ingress.kubernetes.io/force-ssl-redirect" "true" -}}
{{- $_ := set $anns "nginx.ingress.kubernetes.io/proxy-buffering" "off" -}}
{{- $_ := set $anns "nginx.ingress.kubernetes.io/proxy-request-buffering" "off" -}}
{{- $_ := set $anns "nginx.ingress.kubernetes.io/proxy-max-temp-file-size" "0" -}}
{{- dict "enabled" true "name" (include "groundx.fileAccess.serviceName" .) "data" (dict
  "hostName" $host "path" "/" "annotations" $anns
  "ingressClassName" (dig "ingress" "ingressClassName" "" $in)
  "tls" (list (dict "hosts" (list $host) "secretName" $in.tlsSecretName))) | toYaml -}}
{{- else -}}
enabled: false
{{- end -}}
{{- end }}

{{- define "groundx.fileAccess.caEnv" -}}
{{- if and (eq (include "groundx.fileAccess.create" .) "true") (not (empty .Values.fileAccess.caSecretName)) }}
- name: SSL_CERT_FILE
  value: /var/run/groundx/file-access/ca.crt
{{- end }}
{{- end }}

{{- define "groundx.fileAccess.caMount" -}}
{{- if and (eq (include "groundx.fileAccess.create" .) "true") (not (empty .Values.fileAccess.caSecretName)) }}
- name: file-access-ca
  mountPath: /var/run/groundx/file-access
  readOnly: true
{{- end }}
{{- end }}

{{- define "groundx.fileAccess.caVolume" -}}
{{- if and (eq (include "groundx.fileAccess.create" .) "true") (not (empty .Values.fileAccess.caSecretName)) }}
- name: file-access-ca
  secret:
    secretName: {{ .Values.fileAccess.caSecretName | quote }}
    items:
      - key: ca.crt
        path: ca.crt
{{- end }}
{{- end }}

{{- define "groundx.fileAccess.workloadSecrets" -}}
{{- $root := .root -}}
{{- $secrets := include "groundx.secrets" $root | fromYaml | default dict -}}
{{- $consumers := list "groundx" "fileAccess" "layoutWebhook" "preProcess" "process" "queue" "largeFileDeliver" "summaryClient" "upload" "layout.api" "layout.inference" "layout.correct" "layout.map" "layout.ocr" "layout.process" "layout.save" "extract.api" "extract.agent" "extract.download" "extract.save" -}}
{{- if and (eq (include "groundx.fileAccess.create" $root) "true") (has .service $consumers) -}}
  {{- $name := $root.Values.fileAccess.storageCredentialsSecretName -}}
  {{- if $name -}}{{- $_ := set $secrets $name $name -}}{{- end -}}
{{- end -}}
{{- $secrets | toYaml -}}
{{- end }}
