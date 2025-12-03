{{- define "groundx.app.ingress" -}}
{{- $svcs := dict -}}

{{ $fl := include "groundx.file.ingress" . | fromYaml }}
{{- $fle := dig "enabled" "false" $fl | toString -}}
{{- if eq $fle "true" -}}
{{- $_ := set $svcs "file" "file" -}}
{{- end -}}

{{ $gx := include "groundx.groundx.ingress" . | fromYaml }}
{{- $gxe := dig "enabled" "true" $gx | toString -}}
{{- if eq $gxe "true" -}}
{{- $_ := set $svcs "groundx" "groundx" -}}
{{- end -}}

{{ $ex := include "groundx.extract.api.ingress" . | fromYaml }}
{{- $exe := dig "enabled" "false" $ex | toString -}}
{{- if eq $exe "true" -}}
{{- $_ := set $svcs "extract.api" "extract.api" -}}
{{- end -}}

{{ $lx := include "groundx.layout.api.ingress" . | fromYaml }}
{{- $lxe := dig "enabled" "false" $lx | toString -}}
{{- if eq $lxe "true" -}}
{{- $_ := set $svcs "layout.api" "layout.api" -}}
{{- end -}}

{{ $lwx := include "groundx.layoutWebhook.ingress" . | fromYaml }}
{{- $lwxe := dig "enabled" "false" $lwx | toString -}}
{{- if eq $lwxe "true" -}}
{{- $_ := set $svcs "layoutWebhook" "layoutWebhook" -}}
{{- end -}}

{{ $rx := include "groundx.ranker.api.ingress" . | fromYaml }}
{{- $rxe := dig "enabled" "false" $rx | toString -}}
{{- if eq $rxe "true" -}}
{{- $_ := set $svcs "ranker.api" "ranker.api" -}}
{{- end -}}

{{ $sx := include "groundx.summary.api.ingress" . | fromYaml }}
{{- $sxe := dig "enabled" "false" $sx | toString -}}
{{- if eq $sxe "true" -}}
{{- $_ := set $svcs "summary.api" "summary.api" -}}
{{- end -}}

{{- $svcs | toYaml -}}

{{- end }}
