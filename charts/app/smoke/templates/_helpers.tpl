{{- define "app-smoke.fullname" -}}
{{- .Values.app.name -}}
{{- end -}}

{{- define "app-smoke.componentName" -}}
{{- printf "%s-%s" (include "app-smoke.fullname" .root) .component -}}
{{- end -}}

{{- define "app-smoke.labels" -}}
app.kubernetes.io/name: {{ include "app-smoke.fullname" .root }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/managed-by: Helm
{{- range $key, $value := .root.Values.commonLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}
