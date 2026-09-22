{{- define "expert-listing.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{- define "expert-listing.labels" -}}
{{ include "expert-listing.selectorLabels" . }}
app.kubernetes.io/part-of: expert-listing
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
environment: {{ required "global.environment is required" .root.Values.global.environment }}
{{- end }}

{{- define "expert-listing.image" -}}
{{- if eq .image.tag "latest" }}{{ fail "image tag 'latest' is not allowed; deploy an immutable git SHA" }}{{ end -}}
{{- printf "%s/%s:%s" (required "global.imageRegistry is required" .root.Values.global.imageRegistry) .image.repository .image.tag }}
{{- end }}
