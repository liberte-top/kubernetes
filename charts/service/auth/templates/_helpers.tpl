{{- define "service-auth.fullname" -}}
{{- .Values.app.name -}}
{{- end -}}

{{- define "service-auth.componentName" -}}
{{- printf "%s-%s" (include "service-auth.fullname" .root) .component -}}
{{- end -}}

{{- define "service-auth.labels" -}}
app.kubernetes.io/name: {{ include "service-auth.fullname" .root }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/managed-by: Helm
{{- end -}}
