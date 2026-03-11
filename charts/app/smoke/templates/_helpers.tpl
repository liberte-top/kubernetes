{{- define "app-smoke.fullname" -}}
{{- .Values.app.name -}}
{{- end -}}

{{- define "app-smoke.componentName" -}}
{{- printf "%s-%s" (include "app-smoke.fullname" .root) .component -}}
{{- end -}}
