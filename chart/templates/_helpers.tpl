{{- define "ofpr-info.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ofpr-info.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ofpr-info.labels" -}}
app.kubernetes.io/name: {{ include "ofpr-info.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "ofpr-info.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ofpr-info.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ofpr-info.secretName" -}}
{{- printf "%s-env" (include "ofpr-info.fullname" .) -}}
{{- end -}}

{{- define "ofpr-info.tlsSecretName" -}}
{{- default (printf "%s-tls" (include "ofpr-info.fullname" .)) .Values.ingress.tlsSecretName -}}
{{- end -}}

{{- define "ofpr-info.postgresHost" -}}
{{- printf "%s-postgres" (include "ofpr-info.fullname" .) -}}
{{- end -}}
