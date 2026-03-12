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

{{- define "app-smoke.component" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $values := .values -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
  namespace: {{ $root.Values.namespace }}
  labels:
    app: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
{{ include "app-smoke.labels" (dict "root" $root "component" $name) | indent 4 }}
spec:
  replicas: {{ $values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
  template:
    metadata:
      labels:
        app: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
{{ include "app-smoke.labels" (dict "root" $root "component" $name) | indent 8 }}
{{- with $root.Values.podAnnotations }}
      annotations:
{{ toYaml . | indent 8 }}
{{- end }}
    spec:
      containers:
        - name: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
          image: {{ $values.image.repository }}:{{ $values.image.tag }}
          imagePullPolicy: {{ $values.image.pullPolicy }}
{{- with $values.env }}
          env:
{{- range $key, $value := . }}
            - name: {{ $key }}
              value: {{ $value | quote }}
{{- end }}
{{- end }}
          ports:
            - containerPort: {{ $values.port }}
              name: http
          readinessProbe:
            httpGet:
              path: {{ $values.readinessProbe.path }}
              port: {{ $values.port }}
            initialDelaySeconds: {{ $values.readinessProbe.initialDelaySeconds }}
            periodSeconds: {{ $values.readinessProbe.periodSeconds }}
          livenessProbe:
            httpGet:
              path: {{ $values.livenessProbe.path }}
              port: {{ $values.port }}
            initialDelaySeconds: {{ $values.livenessProbe.initialDelaySeconds }}
            periodSeconds: {{ $values.livenessProbe.periodSeconds }}
{{- with $values.resources }}
          resources:
{{ toYaml . | indent 12 }}
{{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
  namespace: {{ $root.Values.namespace }}
  labels:
    app: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
{{ include "app-smoke.labels" (dict "root" $root "component" $name) | indent 4 }}
spec:
  type: ClusterIP
  selector:
    app: {{ include "app-smoke.componentName" (dict "root" $root "component" $name) }}
  ports:
    - name: http
      port: {{ $values.service.port }}
      targetPort: {{ $values.port }}
{{- end -}}

{{- define "app-smoke.ingressAnnotations" -}}
{{- range $key, $value := .Values.ingress.annotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "app-smoke.ingressTls" -}}
tls:
  - hosts:
      - {{ .Values.ingress.host }}
    secretName: {{ .Values.ingress.tlsSecretName }}
{{- end -}}
