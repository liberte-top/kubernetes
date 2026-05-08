{{- define "crates.fullname" -}}
{{- .Values.app.name -}}
{{- end -}}

{{- define "crates.componentName" -}}
{{- printf "%s-%s" (include "crates.fullname" .root) .component -}}
{{- end -}}

{{- define "crates.labels" -}}
app.kubernetes.io/name: {{ include "crates.fullname" .root }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/managed-by: Helm
{{- range $key, $value := .root.Values.commonLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "crates.ingressAnnotations" -}}
{{- range $key, $value := .Values.ingress.annotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "crates.ingressTls" -}}
{{- if .Values.ingress.tls.enabled }}
tls:
  - hosts:
      - {{ .Values.ingress.host }}
    secretName: {{ .Values.ingress.tls.secretName }}
{{- end }}
{{- end -}}
