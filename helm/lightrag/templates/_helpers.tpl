{{/*
Expand the name of the chart.
*/}}
{{- define "lightrag.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "lightrag.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "lightrag.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "lightrag.labels" -}}
helm.sh/chart: {{ include "lightrag.chart" . }}
{{ include "lightrag.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lightrag.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lightrag.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component labels
*/}}
{{- define "lightrag.componentLabels" -}}
{{- $component := . }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "lightrag.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "lightrag.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate the publish domain
*/}}
{{- define "lightrag.publishDomain" -}}
{{- .Values.global.publishDomain }}
{{- end }}

{{/*
Generate full hostname
*/}}
{{- define "lightrag.hostname" -}}
{{- $subdomain := .subdomain }}
{{- $domain := .domain }}
{{- if $subdomain }}
{{- printf "%s.%s" $subdomain $domain }}
{{- else }}
{{- $domain }}
{{- end }}
{{- end }}

{{/*
Redis password secret name
*/}}
{{- define "lightrag.redis.secretName" -}}
{{- if .Values.redis.auth.existingSecret }}
{{- .Values.redis.auth.existingSecret }}
{{- else }}
{{- printf "%s-secrets" (include "lightrag.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Redis password secret key
*/}}
{{- define "lightrag.redis.secretKey" -}}
{{- if .Values.redis.auth.existingSecretKey }}
{{- .Values.redis.auth.existingSecretKey }}
{{- else }}
{{- "REDIS_PASSWORD" }}
{{- end }}
{{- end }}

{{/*
Storage class name
*/}}
{{- define "lightrag.storageClass" -}}
{{- if .Values.global.storageClass }}
{{- .Values.global.storageClass }}
{{- end }}
{{- end }}
