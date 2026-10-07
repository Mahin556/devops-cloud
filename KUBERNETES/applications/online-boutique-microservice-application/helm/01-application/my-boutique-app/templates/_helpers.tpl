{{/*
Expand the name of the chart.
*/}}

{{- define "01-application.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "01-application.fullname" -}}
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
{{- define "01-application.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* ---------- Identity labels: NEVER change after install ---------- */}}
{{- define "01-application.selectorLabels" -}}
{{- $root := index . 0 -}}
{{- $name := index . 1 -}}
app.kubernetes.io/name: {{ include "01-application.name" $root }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/microservice: {{ $name }}
{{- end }}

{{/* ---------- Metadata labels: informational, can change ---------- */}}
{{- define "01-application.metadataLabels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/environment: {{ .Values.environment | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "adservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "01-application.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap to use
*/}}
{{- define "01-application.configmapName" -}}
{{- if .Values.configmap.name -}}
{{ .Values.configmap.name }}
{{- else -}}
{{ printf "%s-%s-configmap" (include "01-application.fullname" .) .Values.environment }}
{{- end -}}
{{- end }}