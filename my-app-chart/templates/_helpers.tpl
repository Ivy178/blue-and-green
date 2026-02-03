{{/* 定义应用全名称：应用名-环境标识 */}}
{{- define "my-app-bluegreen.fullname" -}}
{{- printf "%s-%s" .Values.app.name .Values.app.env -}}
{{- end -}}

{{/* 定义应用标签 */}}
{{- define "my-app-bluegreen.labels" -}}
app: {{ .Values.app.name }}
env: {{ .Values.app.env }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}