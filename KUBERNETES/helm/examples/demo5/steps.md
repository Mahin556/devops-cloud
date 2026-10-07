```bash
helm lint <path> #Show syntactical error in chart while creating a chart

helm template <path> #Dynamically render a kubernetes manifest file without installing application on cluster.

heml install <release> <path> --dry-run #Dry run + render + not apply + show error that can occure when acutially deploy + what action performed when actually deploy

helm --help

helm template --help

```
```bash
https://artifacthub.io/

helm repo --help

helm repo add groundhog2k https://groundhog2k.github.io/helm-charts/

helm install my-redis groundhog2k/redis --version 2.2.1

helm pull --untar bitnami/wordpress --version 22.4.17

helm upgrade wordpress . --values custom-values.yaml

helm history <revision>

helm rollback <release> <revision_number>
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ default "app" .Values.name }}-configmap
data:
  message: "Hello World"
  drink: {{ .Values.drink | upper | quote }}
  food: {{ .Values.food | title | quote }}
  region: {{ required "region MUST be set" .Values.region | lower | quote }}
```
```bash
https://helm.sh/docs/chart_template_guide/function_list/
```
```yaml
# 🎯 HELM IF / ELSE TEMPLATE GUIDE

# 1️⃣ Choose container image based on environment
containers:
{{- if eq .Values.environment "prod" }}
  - image: webapp:prod
{{- else if eq .Values.environment "dev" }}
  - image: webapp:dev
{{- else }}
  - image: webapp:demo
{{- end }}

# 2️⃣ Conditionally create a ServiceAccount
{{- if .Values.serviceaccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: default
{{- end }}
```
```yaml
environment: dev

serviceaccount:
  create: true
```
```bash
helm template .
helm template . --set environment=dev
helm status <revision>
```

```yaml
# 🎯 HELM `with` BLOCK — CLEANER TEMPLATES

# 1️⃣ Basic usage
metadata:
  name: {{ .Values.name }}
  labels:
{{- with .Values.labels }}
    app: {{ .app }}
    env: {{ .env }}
{{- end }}

# 2️⃣ Nested object shortcut
spec:
{{- with .Values.service }}
  type: {{ .type }}
  ports:
    - port: {{ .port }}
      targetPort: {{ .targetPort }}
{{- end }}

# 3️⃣ Combine with defaults
{{- with .Values.resources }}
resources:
  requests:
    cpu: {{ default "100m" .requests.cpu }}
    memory: {{ default "128Mi" .requests.memory }}
{{- end }}

# 4️⃣ Safe null skip
# (if .Values.resources doesn’t exist → this whole block disappears)
{{- with .Values.resources }}
resources:
  limits:
    cpu: {{ .limits.cpu }}
    memory: {{ .limits.memory }}
{{- end }}

# 📌 values.yaml example
name: myapp
labels:
  app: webapp
  env: prod
service:
  type: ClusterIP
  port: 80
  targetPort: 8080
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

# 🧠 Why use `with`?
# ✔ Avoid repeating .Values.<path> many times
# ✔ Cleaner and shorter templates
# ✔ Block removed automatically if value missing
```

```yaml
# 🎯 HELM NESTED `with` BLOCKS — CLEAN DEPLOYMENT TEMPLATE

{{- with .Values.deployment }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
spec:
  replicas: {{ .replicas }}
  selector:
    matchLabels:
      app: {{ .name }}
  template:
    metadata:
      labels:
        app: {{ .name }}
    spec:
      containers:
{{- with .image }}
      - name: {{ $.Values.deployment.name }}-deployment
        image: {{ .repository }}:{{ .tag }}
        imagePullPolicy: {{ .pullPolicy }}
{{- end }}             # end .image

{{- with .ports }}
        ports:
        - containerPort: {{ .port1 }}
        - containerPort: {{ .port2 }}
{{- end }}             # end .ports

{{- end }}             # end .deployment
```
```yaml
deployment:
  name: webapp
  replicas: 3

  image:
    repository: nginx
    tag: "1.25"
    pullPolicy: IfNotPresent

  ports:
    port1: 80
    port2: 8080
```
```yaml
. = .Values.deployment.image
```
```yaml
# 🎯 HELM RANGE LOOP — ITERATE OVER LISTS AND MAPS

# 1️⃣ Loop through a list of ports
ports:
{{- range .Values.ports }}
  - containerPort: {{ . }}
{{- end }}

# values.yaml
ports:
  - 80
  - 8080
  - 9090

# Result
ports:
- containerPort: 80
- containerPort: 8080
- containerPort: 9090
```
```yaml
# 2️⃣ Loop through objects (list of maps)
env:
{{- range .Values.env }}
  - name: {{ .name }}
    value: {{ .value | quote }}
{{- end }}

# values.yaml
env:
  - name: DB_HOST
    value: mysql
  - name: DB_PORT
    value: "3306"

# Result
env:
- name: DB_HOST
  value: "mysql"
- name: DB_PORT
  value: "3306"
```
```yaml
# 3️⃣ Loop through a dictionary (map)
labels:
{{- range $key, $value := .Values.labels }}
  {{ $key }}: {{ $value }}
{{- end }}

# values.yaml
labels:
  app: webapp
  env: prod
  region: ap-south-1

# Result
labels:
  app: webapp
  env: prod
  region: ap-south-1
```
```yaml
# 4️⃣ Range with index + value
{{- range $i, $port := .Values.ports }}
- name: port-{{ $i }}
  containerPort: {{ $port }}
{{- end }}

# values.yaml
ports:
  - 80
  - 8080

# Result
- name: port-0
  containerPort: 80
- name: port-1
  containerPort: 8080
```
```yaml
# 5️⃣ Break out of range logic using if
env:
{{- range .Values.env }}
{{- if .enabled }}
- name: {{ .name }}
  value: {{ .value }}
{{- end }}
{{- end }}

# values.yaml
env:
  - name: DEBUG
    value: "true"
    enabled: true
  - name: TRACE
    value: "false"
    enabled: false

# Result (only prints DEBUG var)
env:
- name: DEBUG
  value: true
```
```yaml
# 🎯 HELM RANGE WITH OBJECTS — DYNAMIC ROLE BINDINGS

# templates/rolebinding.yaml
{{- range .Values.users }}
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ .name }}-role-binding
subjects:
  - kind: User
    name: {{ .name }}
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: {{ .role }}
  apiGroup: rbac.authorization.k8s.io
---
{{- end }}
```
```yaml
users:
  - name: Alice
    role: admin
  - name: Bob
    role: editor
  - name: Charlie
    role: viewer
```
```yaml
# 🎯 HELM NAMED TEMPLATES (define + template)

# 1️⃣ Define a named template (create a helper)
# File: templates/_helpers.tpl

{{- define "webapp.fullname" -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

# Another helper example
{{- define "webapp.image" -}}
{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}
```
```yaml
# 2️⃣ Use (call) the template in Deployment
# File: templates/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "webapp.fullname" . }}
spec:
  replicas: {{ .Values.replicas }}
  template:
    spec:
      containers:
        - name: webapp
          image: {{ template "webapp.image" . }}
```

```yaml
# 3️⃣ You can pass a different scope using `include`
name: {{ include "webapp.fullname" . }}
labels:
{{ include "webapp.labels" . | indent 2 }}
# 4️⃣ Add a labels helper (very common)
# File: _helpers.tpl

{{- define "webapp.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

metadata:
  labels:
{{ include "webapp.labels" . | nindent 4 }}

```
```yaml
# 🎯 HELM NAMED TEMPLATES — FULL WORKING EXAMPLE

# ----------------------------------------------------
# 1️⃣ Define reusable labels in _helpers.tpl
# ----------------------------------------------------
# File: templates/_helpers.tpl

{{- define "labels" -}}
app: nginx
env: dev
{{- end }}
```
```yaml
# ----------------------------------------------------
# 2️⃣ Use `template` to insert text (no indentation fix)
# ----------------------------------------------------
metadata:
  labels:
    {{- template "labels" }}
```
```yaml
# ----------------------------------------------------
# 3️⃣ Use `include` + indent (correct & recommended)
# ----------------------------------------------------
metadata:
  labels:
{{- include "labels" . | indent 4 }}
```
```yaml
# ----------------------------------------------------
# 4️⃣ Deployment using include (correct format)
# File: templates/deployment.yaml
# ----------------------------------------------------

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
{{- include "labels" . | indent 2 }}
spec:
  replicas: 1
  selector:
    matchLabels:
{{- include "labels" . | indent 6 }}
  template:
    metadata:
      labels:
{{- include "labels" . | indent 8 }}
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```
```yaml
# ----------------------------------------------------
# 5️⃣ Reused in service.yaml
# File: templates/service.yaml
# ----------------------------------------------------

apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
{{- include "labels" . | indent 4 }}
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```