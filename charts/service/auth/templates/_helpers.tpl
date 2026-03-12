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
{{- range $key, $value := .root.Values.commonLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "service-auth.component" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $values := .values -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
  namespace: {{ $root.Values.namespace }}
  labels:
    app: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
{{ include "service-auth.labels" (dict "root" $root "component" $name) | indent 4 }}
spec:
  replicas: {{ $values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
  template:
    metadata:
      labels:
        app: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
{{ include "service-auth.labels" (dict "root" $root "component" $name) | indent 8 }}
{{- with $root.Values.podAnnotations }}
      annotations:
{{ toYaml . | indent 8 }}
{{- end }}
    spec:
      containers:
        - name: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
          image: {{ $values.image.repository }}:{{ $values.image.tag }}
          imagePullPolicy: {{ $values.image.pullPolicy }}
{{- with $values.env }}
          env:
{{- range $key, $value := . }}
            - name: {{ $key }}
              value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- with $values.secretEnv }}
{{- range $key, $value := . }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ $value.secretName }}
                  key: {{ $value.secretKey }}
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
  name: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
  namespace: {{ $root.Values.namespace }}
  labels:
    app: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
{{ include "service-auth.labels" (dict "root" $root "component" $name) | indent 4 }}
spec:
  type: ClusterIP
  selector:
    app: {{ include "service-auth.componentName" (dict "root" $root "component" $name) }}
  ports:
    - name: http
      port: {{ $values.service.port }}
      targetPort: {{ $values.port }}
{{- end -}}

{{- define "service-auth.ingressAnnotations" -}}
{{- range $key, $value := .Values.ingress.annotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "service-auth.ingressTls" -}}
tls:
  - hosts:
      - {{ .Values.ingress.host }}
    secretName: {{ .Values.ingress.tlsSecretName }}
{{- end -}}
