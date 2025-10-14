{{- define "groundx.stream.node" -}}
{{- $in := .Values.stream | default dict -}}
{{- $df := include "groundx.node.cpuOnly" . -}}
{{ dig "node" $df $in }}
{{- end }}

{{- define "groundx.stream.serviceName" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "serviceName" "stream" $in }}
{{- end }}

{{- define "groundx.stream.existing" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{ not (empty (dig "domain" "" $ex)) }}
{{- end }}

{{- define "groundx.stream.create" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
false
{{- else if hasKey $in "enabled" -}}
  {{- if (dig "enabled" false $in) -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "groundx.stream.key" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "key" nil $in }}
{{- end }}

{{- define "groundx.stream.replicas" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "replicas" 1 $in }}
{{- end }}

{{- define "groundx.stream.secret" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "secret" nil $in }}
{{- end }}

{{- define "groundx.stream.serviceHost" -}}
{{- $ns := include "groundx.ns" . -}}
{{- $name := include "groundx.stream.serviceName" . -}}
{{- printf "%s-cluster-kafka-bootstrap.%s.svc.cluster.local" $name $ns -}}
{{- end }}

{{- define "groundx.stream.domain" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "domain" "" $ex }}
{{- else -}}
{{ include "groundx.stream.serviceHost" . }}
{{- end -}}
{{- end }}

{{- define "groundx.stream.port" -}}
{{- $in := .Values.stream | default dict -}}
{{- $ex := dig "existing" dict $in -}}
{{- $ic := include "groundx.stream.existing" . | trim | lower -}}
{{- if eq $ic "true" -}}
{{ dig "port" 9092 $ex }}
{{- else -}}
{{ dig "port" 9092 $in }}
{{- end -}}
{{- end }}

{{- define "groundx.stream.retention" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "retention" "1073741824" $in }}
{{- end }}

{{- define "groundx.stream.segment" -}}
{{- $in := .Values.stream | default dict -}}
{{ dig "segment" "1073741824" $in }}
{{- end }}

{{- define "groundx.stream.topic.preProcess" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $key := include "groundx.stream.key" . -}}
{{- $secret := include "groundx.stream.secret" . -}}
{{- $cfg := dict
  "broker"  (printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .))
  "groupId" (printf "%s-%s" (include "groundx.ns" .) (include "groundx.stream.serviceName" .))
  "topic"   ("file-pre-process")
  "type"    ("kafka")
-}}
{{- if hasKey $topics "preProcess" -}}
{{- $pp := index $topics "preProcess" -}}
{{- $ty := dig "type" "" $pp | lower -}}
{{- if eq $ty "kafka" -}}
{{- if hasKey $pp "broker" -}}
{{- $_ := set $cfg "broker" (index $pp "broker") -}}
{{- end -}}
{{- if hasKey $pp "groupId" -}}
{{- $_ := set $cfg "groupId" (index $pp "groupId") -}}
{{- end -}}
{{- if hasKey $pp "topic" -}}
{{- $_ := set $cfg "topic" (index $pp "topic") -}}
{{- end -}}
{{- else if eq $ty "sqs" -}}
{{- if and (hasKey $pp "region") (hasKey $pp "url") -}}
{{- $cfg = dict
  "region" (index $pp "region")
  "topic"  ("file-pre-process")
  "type"   ("sqs")
  "url"    (index $pp "url")
-}}
{{- if or (hasKey $pp "key") $key -}}
{{- $_ := set $cfg "key" (coalesce (index $pp "key") $key) -}}
{{- end -}}
{{- if or (hasKey $pp "secret") $secret -}}
{{- $_ := set $cfg "secret" (coalesce (index $pp "secret") $secret) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.process" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $key := include "groundx.stream.key" . -}}
{{- $secret := include "groundx.stream.secret" . -}}
{{- $cfg := dict
  "broker"  (printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .))
  "groupId" (printf "%s-%s" (include "groundx.ns" .) (include "groundx.stream.serviceName" .))
  "topic"   ("file-process")
  "type"    ("kafka")
-}}
{{- if hasKey $topics "process" -}}
{{- $pp := index $topics "process" -}}
{{- $ty := dig "type" "" $pp | lower -}}
{{- if eq $ty "kafka" -}}
{{- if hasKey $pp "broker" -}}
{{- $_ := set $cfg "broker" (index $pp "broker") -}}
{{- end -}}
{{- if hasKey $pp "groupId" -}}
{{- $_ := set $cfg "groupId" (index $pp "groupId") -}}
{{- end -}}
{{- if hasKey $pp "topic" -}}
{{- $_ := set $cfg "topic" (index $pp "topic") -}}
{{- end -}}
{{- else if eq $ty "sqs" -}}
{{- if and (hasKey $pp "region") (hasKey $pp "url") -}}
{{- $cfg = dict
  "region" (index $pp "region")
  "topic"  ("file-process")
  "type"   ("sqs")
  "url"    (index $pp "url")
-}}
{{- if or (hasKey $pp "key") $key -}}
{{- $_ := set $cfg "key" (coalesce (index $pp "key") $key) -}}
{{- end -}}
{{- if or (hasKey $pp "secret") $secret -}}
{{- $_ := set $cfg "secret" (coalesce (index $pp "secret") $secret) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.summary" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $key := include "groundx.stream.key" . -}}
{{- $secret := include "groundx.stream.secret" . -}}
{{- $cfg := dict
  "broker"  (printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .))
  "groupId" (printf "%s-%s" (include "groundx.ns" .) (include "groundx.stream.serviceName" .))
  "topic"   ("file-summary")
  "type"    ("kafka")
-}}
{{- if hasKey $topics "summary" -}}
{{- $pp := index $topics "summary" -}}
{{- $ty := dig "type" "" $pp | lower -}}
{{- if eq $ty "kafka" -}}
{{- if hasKey $pp "broker" -}}
{{- $_ := set $cfg "broker" (index $pp "broker") -}}
{{- end -}}
{{- if hasKey $pp "groupId" -}}
{{- $_ := set $cfg "groupId" (index $pp "groupId") -}}
{{- end -}}
{{- if hasKey $pp "topic" -}}
{{- $_ := set $cfg "topic" (index $pp "topic") -}}
{{- end -}}
{{- else if eq $ty "sqs" -}}
{{- if and (hasKey $pp "region") (hasKey $pp "url") -}}
{{- $cfg = dict
  "region" (index $pp "region")
  "topic"  ("file-summary")
  "type"   ("sqs")
  "url"    (index $pp "url")
-}}
{{- if or (hasKey $pp "key") $key -}}
{{- $_ := set $cfg "key" (coalesce (index $pp "key") $key) -}}
{{- end -}}
{{- if or (hasKey $pp "secret") $secret -}}
{{- $_ := set $cfg "secret" (coalesce (index $pp "secret") $secret) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.update" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $key := include "groundx.stream.key" . -}}
{{- $secret := include "groundx.stream.secret" . -}}
{{- $cfg := dict
  "broker"  (printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .))
  "groupId" (printf "%s-%s" (include "groundx.ns" .) (include "groundx.stream.serviceName" .))
  "topic"   ("file-update")
  "type"    ("kafka")
-}}
{{- if hasKey $topics "update" -}}
{{- $pp := index $topics "update" -}}
{{- $ty := dig "type" "" $pp | lower -}}
{{- if eq $ty "kafka" -}}
{{- if hasKey $pp "broker" -}}
{{- $_ := set $cfg "broker" (index $pp "broker") -}}
{{- end -}}
{{- if hasKey $pp "groupId" -}}
{{- $_ := set $cfg "groupId" (index $pp "groupId") -}}
{{- end -}}
{{- if hasKey $pp "topic" -}}
{{- $_ := set $cfg "topic" (index $pp "topic") -}}
{{- end -}}
{{- else if eq $ty "sqs" -}}
{{- if and (hasKey $pp "region") (hasKey $pp "url") -}}
{{- $cfg = dict
  "region" (index $pp "region")
  "topic"  ("file-update")
  "type"   ("sqs")
  "url"    (index $pp "url")
-}}
{{- if or (hasKey $pp "key") $key -}}
{{- $_ := set $cfg "key" (coalesce (index $pp "key") $key) -}}
{{- end -}}
{{- if or (hasKey $pp "secret") $secret -}}
{{- $_ := set $cfg "secret" (coalesce (index $pp "secret") $secret) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.upload" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $key := include "groundx.stream.key" . -}}
{{- $secret := include "groundx.stream.secret" . -}}
{{- $cfg := dict
  "broker"  (printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .))
  "groupId" (printf "%s-%s" (include "groundx.ns" .) (include "groundx.stream.serviceName" .))
  "topic"   ("file-upload")
  "type"    ("kafka")
-}}
{{- if hasKey $topics "upload" -}}
{{- $pp := index $topics "upload" -}}
{{- $ty := dig "type" "" $pp | lower -}}
{{- if eq $ty "kafka" -}}
{{- if hasKey $pp "broker" -}}
{{- $_ := set $cfg "broker" (index $pp "broker") -}}
{{- end -}}
{{- if hasKey $pp "groupId" -}}
{{- $_ := set $cfg "groupId" (index $pp "groupId") -}}
{{- end -}}
{{- if hasKey $pp "topic" -}}
{{- $_ := set $cfg "topic" (index $pp "topic") -}}
{{- end -}}
{{- else if eq $ty "sqs" -}}
{{- if and (hasKey $pp "region") (hasKey $pp "url") -}}
{{- $cfg = dict
  "region" (index $pp "region")
  "topic"  ("file-upload")
  "type"   ("sqs")
  "url"    (index $pp "url")
-}}
{{- if or (hasKey $pp "key") $key -}}
{{- $_ := set $cfg "key" (coalesce (index $pp "key") $key) -}}
{{- end -}}
{{- if or (hasKey $pp "secret") $secret -}}
{{- $_ := set $cfg "secret" (coalesce (index $pp "secret") $secret) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topics" -}}
{{- $cfg := dict -}}

{{- $pp := (include "groundx.stream.topic.preProcess" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp | lower) "kafka" -}}
  {{- $rep := (include "groundx.preProcess.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.process" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp | lower) "kafka" -}}
  {{- $rep := (include "groundx.process.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.summary" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp | lower) "kafka" -}}
  {{- $rep := (include "groundx.summaryClient.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.update" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp | lower) "kafka" -}}
  {{- $rep := (include "groundx.queue.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.upload" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp | lower) "kafka" -}}
  {{- $rep := (include "groundx.upload.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $cfg | toYaml -}}

{{- end }}
