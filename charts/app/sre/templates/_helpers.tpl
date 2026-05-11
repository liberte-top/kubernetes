{{- define "app-sre.fullname" -}}
{{- .Values.app.name -}}
{{- end -}}

{{- define "app-sre.componentName" -}}
{{- printf "%s-%s" (include "app-sre.fullname" .root) .component -}}
{{- end -}}

{{- define "app-sre.labels" -}}
app.kubernetes.io/name: {{ include "app-sre.fullname" .root }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/managed-by: Helm
{{- range $key, $value := .root.Values.commonLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "app-sre.component" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $values := .values -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
  namespace: {{ $root.Values.namespace }}
  labels:
    app: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
{{ include "app-sre.labels" (dict "root" $root "component" $name) | indent 4 }}
spec:
  replicas: {{ $values.replicaCount }}
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
  template:
    metadata:
      labels:
        app: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
{{ include "app-sre.labels" (dict "root" $root "component" $name) | indent 8 }}
{{- with $root.Values.podAnnotations }}
      annotations:
{{ toYaml . | indent 8 }}
{{- end }}
    spec:
{{- if $root.Values.imagePullSecrets }}
      imagePullSecrets:
{{- range $root.Values.imagePullSecrets }}
        - name: {{ . }}
{{- end }}
{{- end }}
      containers:
        - name: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
          image: {{ $values.image.repository }}:{{ $values.image.tag }}
          imagePullPolicy: {{ $values.image.pullPolicy }}
{{- if or $values.env $values.envSecretRefs }}
          env:
{{- with $values.env }}
{{- range $key, $value := . }}
            - name: {{ $key }}
              value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- with $values.envSecretRefs }}
{{- range $name, $ref := . }}
            - name: {{ $name }}
              valueFrom:
                secretKeyRef:
                  name: {{ $ref.secretName }}
                  key: {{ $ref.secretKey }}
                  optional: {{ $ref.optional }}
{{- end }}
{{- end }}
{{- end }}
{{- with $values.envFromSecrets }}
          envFrom:
{{- range . }}
            - secretRef:
                name: {{ .name }}
                optional: {{ .optional }}
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
  name: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
  namespace: {{ $root.Values.namespace }}
  labels:
    app: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
{{ include "app-sre.labels" (dict "root" $root "component" $name) | indent 4 }}
spec:
  type: ClusterIP
  selector:
    app: {{ include "app-sre.componentName" (dict "root" $root "component" $name) }}
  ports:
    - name: http
      port: {{ $values.service.port }}
      targetPort: {{ $values.port }}
{{- end -}}

{{- define "app-sre.ingressAnnotations" -}}
{{- range $key, $value := .Values.ingress.annotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{- define "app-sre.ingressTls" -}}
{{- if .Values.ingress.tls.enabled }}
tls:
  - hosts:
      - {{ .Values.ingress.host }}
    secretName: {{ .Values.ingress.tls.secretName }}
{{- end }}
{{- end -}}
