{{/*
The name is fixed to <release>-mysql so that, installed as release
"weatherapp-auth", the StatefulSet and Service are "weatherapp-auth-mysql" and
the PVC is "data-weatherapp-auth-mysql-0" -- the names the 2021 Bitnami chart
produced, which the CI/CD and backup sections rely on.
*/}}
{{- define "mysql.fullname" -}}
{{- printf "%s-mysql" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "mysql.selectorLabels" -}}
app.kubernetes.io/name: mysql
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "mysql.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{ include "mysql.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/component: database
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
