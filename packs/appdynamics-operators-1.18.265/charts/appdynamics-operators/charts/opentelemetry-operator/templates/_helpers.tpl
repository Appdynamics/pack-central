{{/*
Expand the name of the chart.
*/}}
{{- define "opentelemetry-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "opentelemetry-operator.fullname" -}}
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
{{- define "opentelemetry-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opentelemetry-operator.labels" -}}
helm.sh/chart: {{ include "opentelemetry-operator.chart" . }}
{{ include "opentelemetry-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opentelemetry-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opentelemetry-operator.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "opentelemetry-operator.serviceAccountName" -}}
{{- if .Values.manager.serviceAccount.create }}
{{- default (include "opentelemetry-operator.name" .) .Values.manager.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.manager.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "opentelemetry-operator.podAnnotations" -}}
{{- if .Values.manager.podAnnotations }}
{{- .Values.manager.podAnnotations | toYaml }}
{{- end }}
{{- end }}

{{- define "opentelemetry-operator.podLabels" -}}
{{- if .Values.manager.podLabels }}
{{- .Values.manager.podLabels | toYaml }}
{{- end }}
{{- end }}

{{/*
Create an ordered name of the MutatingWebhookConfiguration
*/}}
{{- define "opentelemetry-operator.MutatingWebhookName" -}}
{{- printf "%s-%s" (.Values.admissionWebhooks.namePrefix | toString) (include "opentelemetry-operator.fullname" .) | trimPrefix "-" }}
{{- end }}

{{/*
Return certificate and CA for Webhooks.
It handles variants when a cert has to be generated by Helm,
a cert is loaded from an existing secret or is provided via `.Values`
*/}}
{{- define "opentelemetry-operator.WebhookCert" -}}
{{- $caCertEnc := "" }}
{{- $certCrtEnc := "" }}
{{- $certKeyEnc := "" }}
{{- if .Values.admissionWebhooks.autoGenerateCert.enabled }}
{{- $prevSecret := (lookup "v1" "Secret" .Release.Namespace (default (printf "%s-controller-manager-service-cert" (include "opentelemetry-operator.fullname" .)) .Values.admissionWebhooks.secretName )) }}
{{- if and (not .Values.admissionWebhooks.autoGenerateCert.recreate) $prevSecret }}
{{- $certCrtEnc = index $prevSecret "data" "tls.crt" }}
{{- $certKeyEnc = index $prevSecret "data" "tls.key" }}
{{- $caCertEnc = index $prevSecret "data" "ca.crt" }}
{{- if not $caCertEnc }}
{{- $prevHook := (lookup "admissionregistration.k8s.io/v1" "MutatingWebhookConfiguration" .Release.Namespace (print (include "opentelemetry-operator.MutatingWebhookName" . ) "-mutation")) }}
{{- $caCertEnc = (first $prevHook.webhooks).clientConfig.caBundle }}
{{- end }}
{{- else }}
{{- $altNames := list ( printf "%s-webhook.%s" (include "opentelemetry-operator.fullname" .) .Release.Namespace ) ( printf "%s-webhook.%s.svc" (include "opentelemetry-operator.fullname" .) .Release.Namespace ) -}}
{{- $ca := genCA "opentelemetry-operator-operator-ca" 365 }}
{{- $cert := genSignedCert (include "opentelemetry-operator.fullname" .) nil $altNames 365 $ca }}
{{- $certCrtEnc = b64enc $cert.Cert }}
{{- $certKeyEnc = b64enc $cert.Key }}
{{- $caCertEnc = b64enc $ca.Cert }}
{{- end }}
{{- else }}
{{- $certCrtEnc = b64enc .Values.admissionWebhooks.cert_file }}
{{- $certKeyEnc = b64enc .Values.admissionWebhooks.key_file }}
{{- $caCertEnc = b64enc .Values.admissionWebhooks.ca_file }}
{{- end }}
{{- $result := dict "crt" $certCrtEnc "key" $certKeyEnc "ca" $caCertEnc }}
{{- $result | toYaml }}
{{- end }}