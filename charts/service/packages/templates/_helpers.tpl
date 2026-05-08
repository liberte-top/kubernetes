{{- define "packages.fullname" -}}
{{- .Values.app.name -}}
{{- end -}}

{{- define "packages.componentName" -}}
{{- printf "%s-%s" (include "packages.fullname" .root) .component -}}
{{- end -}}

{{- define "packages.labels" -}}
app.kubernetes.io/name: {{ include "packages.fullname" .root }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/managed-by: Helm
{{- range $key, $value := .root.Values.commonLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "packages.ingressAnnotations" -}}
{{- range $key, $value := .Values.ingress.annotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "packages.ingressTls" -}}
{{- if .Values.ingress.tls.enabled }}
tls:
  - hosts:
      - {{ .Values.ingress.host }}
    secretName: {{ .Values.ingress.tls.secretName }}
{{- end }}
{{- end -}}
