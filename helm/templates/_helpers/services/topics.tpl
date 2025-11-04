{{- define "groundx.stream.hasKafka" -}}
{{- $t1 := (include "groundx.stream.topic.process" . | fromYaml) -}}
{{- $t2 := (include "groundx.stream.topic.preProcess" . | fromYaml) -}}
{{- $t3 := (include "groundx.stream.topic.summary" . | fromYaml) -}}
{{- $t4 := (include "groundx.stream.topic.update" . | fromYaml) -}}
{{- $t5 := (include "groundx.stream.topic.upload" . | fromYaml) -}}
{{- if or (eq (dig "type" "" $t1) "kafka") (eq (dig "type" "" $t2) "kafka") (eq (dig "type" "" $t3) "kafka") (eq (dig "type" "" $t4) "kafka") (eq (dig "type" "" $t5) "kafka") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "groundx.stream.topic.preProcess" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $topic := dig "preProcess" dict $topics -}}
{{- $broker := printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .) -}}
{{- $key := coalesce (dig "key" "" $topic | trim) (include "groundx.stream.key" .) -}}
{{- $region := coalesce (dig "region" "" $topic | trim) (include "groundx.stream.region" .) -}}
{{- $secret := coalesce (dig "secret" "" $topic | trim) (include "groundx.stream.secret" .) -}}
{{- $token := coalesce (dig "token" "" $topic | trim) (include "groundx.stream.token" .) -}}
{{- $ty := (dig "type" "kafka" $topic) | lower -}}

{{- $cfg := dict
  "type"    ($ty)
-}}

{{- if eq $ty "kafka" -}}
  {{- $name := dig "topic" "file-pre-process" $topic -}}
  {{- $_ := set $cfg "broker" (dig "broker" $broker $topic) -}}
  {{- $_ := set $cfg "groupId" (dig "groupId" $name $topic) -}}
  {{- $_ := set $cfg "topic" $name -}}
{{- end -}}

{{- if and $key (ne $key "") -}}
  {{- $_ := set $cfg "key" $key -}}
{{- end -}}

{{- if and $region (ne $region "") -}}
  {{- $_ := set $cfg "region" $region -}}
{{- end -}}

{{- if and $secret (ne $secret "") -}}
  {{- $_ := set $cfg "secret" $secret -}}
{{- end -}}

{{- if and $token (ne $token "") -}}
  {{- $_ := set $cfg "token" $token -}}
{{- end -}}

{{- if hasKey $topic "url" -}}
  {{- $_ := set $cfg "url" (dig "url" "" $topic) -}}
{{- end -}}

{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.process" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $topic := dig "process" dict $topics -}}
{{- $broker := printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .) -}}
{{- $key := coalesce (dig "key" "" $topic | trim) (include "groundx.stream.key" .) -}}
{{- $region := coalesce (dig "region" "" $topic | trim) (include "groundx.stream.region" .) -}}
{{- $secret := coalesce (dig "secret" "" $topic | trim) (include "groundx.stream.secret" .) -}}
{{- $token := coalesce (dig "token" "" $topic | trim) (include "groundx.stream.token" .) -}}
{{- $ty := (dig "type" "kafka" $topic) | lower -}}

{{- $cfg := dict
  "type"    ($ty)
-}}

{{- if eq $ty "kafka" -}}
  {{- $name := dig "topic" "file-process" $topic -}}
  {{- $_ := set $cfg "broker" (dig "broker" $broker $topic) -}}
  {{- $_ := set $cfg "groupId" (dig "groupId" $name $topic) -}}
  {{- $_ := set $cfg "topic" $name -}}
{{- end -}}

{{- if and $key (ne $key "") -}}
  {{- $_ := set $cfg "key" $key -}}
{{- end -}}

{{- if and $region (ne $region "") -}}
  {{- $_ := set $cfg "region" $region -}}
{{- end -}}

{{- if and $secret (ne $secret "") -}}
  {{- $_ := set $cfg "secret" $secret -}}
{{- end -}}

{{- if and $token (ne $token "") -}}
  {{- $_ := set $cfg "token" $token -}}
{{- end -}}

{{- if hasKey $topic "url" -}}
  {{- $_ := set $cfg "url" (dig "url" "" $topic) -}}
{{- end -}}

{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.summary" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $topic := dig "summary" dict $topics -}}
{{- $broker := printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .) -}}
{{- $key := coalesce (dig "key" "" $topic | trim) (include "groundx.stream.key" .) -}}
{{- $region := coalesce (dig "region" "" $topic | trim) (include "groundx.stream.region" .) -}}
{{- $secret := coalesce (dig "secret" "" $topic | trim) (include "groundx.stream.secret" .) -}}
{{- $token := coalesce (dig "token" "" $topic | trim) (include "groundx.stream.token" .) -}}
{{- $ty := (dig "type" "kafka" $topic) | lower -}}

{{- $cfg := dict
  "type"    ($ty)
-}}

{{- if eq $ty "kafka" -}}
  {{- $name := dig "topic" "file-summary" $topic -}}
  {{- $_ := set $cfg "broker" (dig "broker" $broker $topic) -}}
  {{- $_ := set $cfg "groupId" (dig "groupId" $name $topic) -}}
  {{- $_ := set $cfg "topic" $name -}}
{{- end -}}

{{- if and $key (ne $key "") -}}
  {{- $_ := set $cfg "key" $key -}}
{{- end -}}

{{- if and $region (ne $region "") -}}
  {{- $_ := set $cfg "region" $region -}}
{{- end -}}

{{- if and $secret (ne $secret "") -}}
  {{- $_ := set $cfg "secret" $secret -}}
{{- end -}}

{{- if and $token (ne $token "") -}}
  {{- $_ := set $cfg "token" $token -}}
{{- end -}}

{{- if hasKey $topic "url" -}}
  {{- $_ := set $cfg "url" (dig "url" "" $topic) -}}
{{- end -}}

{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.update" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $topic := dig "update" dict $topics -}}
{{- $broker := printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .) -}}
{{- $key := coalesce (dig "key" "" $topic | trim) (include "groundx.stream.key" .) -}}
{{- $region := coalesce (dig "region" "" $topic | trim) (include "groundx.stream.region" .) -}}
{{- $secret := coalesce (dig "secret" "" $topic | trim) (include "groundx.stream.secret" .) -}}
{{- $token := coalesce (dig "token" "" $topic | trim) (include "groundx.stream.token" .) -}}
{{- $ty := (dig "type" "kafka" $topic) | lower -}}

{{- $cfg := dict
  "type"    ($ty)
-}}

{{- if eq $ty "kafka" -}}
  {{- $name := dig "topic" "file-update" $topic -}}
  {{- $_ := set $cfg "broker" (dig "broker" $broker $topic) -}}
  {{- $_ := set $cfg "groupId" (dig "groupId" $name $topic) -}}
  {{- $_ := set $cfg "topic" $name -}}
{{- end -}}

{{- if and $key (ne $key "") -}}
  {{- $_ := set $cfg "key" $key -}}
{{- end -}}

{{- if and $region (ne $region "") -}}
  {{- $_ := set $cfg "region" $region -}}
{{- end -}}

{{- if and $secret (ne $secret "") -}}
  {{- $_ := set $cfg "secret" $secret -}}
{{- end -}}

{{- if and $token (ne $token "") -}}
  {{- $_ := set $cfg "token" $token -}}
{{- end -}}

{{- if hasKey $topic "url" -}}
  {{- $_ := set $cfg "url" (dig "url" "" $topic) -}}
{{- end -}}

{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topic.upload" -}}
{{- $in := .Values.stream | default dict -}}
{{- $topics := dig "topics" dict $in -}}
{{- $topic := dig "upload" dict $topics -}}
{{- $broker := printf "%s:%v" (include "groundx.stream.domain" .) (include "groundx.stream.port" .) -}}
{{- $key := coalesce (dig "key" "" $topic | trim) (include "groundx.stream.key" .) -}}
{{- $region := coalesce (dig "region" "" $topic | trim) (include "groundx.stream.region" .) -}}
{{- $secret := coalesce (dig "secret" "" $topic | trim) (include "groundx.stream.secret" .) -}}
{{- $token := coalesce (dig "token" "" $topic | trim) (include "groundx.stream.token" .) -}}
{{- $ty := (dig "type" "kafka" $topic) | lower -}}

{{- $cfg := dict
  "type"    ($ty)
-}}

{{- if eq $ty "kafka" -}}
  {{- $name := dig "topic" "file-upload" $topic -}}
  {{- $_ := set $cfg "broker" (dig "broker" $broker $topic) -}}
  {{- $_ := set $cfg "groupId" (dig "groupId" $name $topic) -}}
  {{- $_ := set $cfg "topic" $name -}}
{{- end -}}

{{- if and $key (ne $key "") -}}
  {{- $_ := set $cfg "key" $key -}}
{{- end -}}

{{- if and $region (ne $region "") -}}
  {{- $_ := set $cfg "region" $region -}}
{{- end -}}

{{- if and $secret (ne $secret "") -}}
  {{- $_ := set $cfg "secret" $secret -}}
{{- end -}}

{{- if and $token (ne $token "") -}}
  {{- $_ := set $cfg "token" $token -}}
{{- end -}}

{{- if hasKey $topic "url" -}}
  {{- $_ := set $cfg "url" (dig "url" "" $topic) -}}
{{- end -}}

{{- $cfg | toYaml -}}
{{- end }}

{{- define "groundx.stream.topics" -}}
{{- $cfg := dict -}}

{{- $pp := (include "groundx.stream.topic.preProcess" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp) "kafka" -}}
  {{- $rep := (include "groundx.preProcess.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.process" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp) "kafka" -}}
  {{- $rep := (include "groundx.process.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.summary" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp) "kafka" -}}
  {{- $rep := (include "groundx.summaryClient.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.update" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp) "kafka" -}}
  {{- $rep := (include "groundx.queue.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $pp := (include "groundx.stream.topic.upload" . | fromYaml) -}}
{{- if eq (dig "type" "" $pp) "kafka" -}}
  {{- $rep := (include "groundx.upload.replicas" . | fromYaml) -}}
  {{- $desired := int (dig "desired" 1 $rep) -}}
  {{- $_ := set $cfg (index $pp "topic") ($desired) -}}
{{- end -}}

{{- $cfg | toYaml -}}

{{- end }}
