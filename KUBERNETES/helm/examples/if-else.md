## 2. Checking if a Value Exists (Defined)

Use `hasKey` or check against `nil` / `default`.

```yaml
# Check if a key is explicitly set
{{- if hasKey .Values "database" }}
  url: {{ .Values.database.url }}
{{- else }}
  url: "default-db.local"
{{- end }}

# Using default to provide a fallback (simpler)
url: {{ .Values.database.url | default "default-db.local" }}
```

---

## 3. Checking for Empty Values (`""`, `null`, `0`, `false`)

In Helm, the following values evaluate to **false** in an `if` condition:
- `false` (boolean)
- `0` (integer zero)
- An empty string `""`
- `nil` (null)
- An empty collection (map, slice, array)

```yaml
{{- if .Values.replicas }}
replicas: {{ .Values.replicas }}
{{- else }}
replicas: 1   # Will be used if replicas is 0, "", null, or false
{{- end }}
```

---

## 4. Comparison Operators (`eq`, `ne`, `lt`, `gt`, `le`, `ge`)

Helm provides functions for comparisons.

```yaml
{{- if eq .Values.environment "production" }}
  logLevel: "error"
  replicaCount: 5
{{- else if eq .Values.environment "staging" }}
  logLevel: "warn"
  replicaCount: 2
{{- else }}
  logLevel: "debug"
  replicaCount: 1
{{- end }}
```

**Other comparisons:**
```yaml
{{- if gt .Values.cpuRequest 2.0 }}   # Greater than
{{- if lt .Values.memoryLimit 1024 }} # Less than
{{- if ne .Values.mode "off" }}       # Not equal
{{- if le .Values.pods 10 }}          # Less than or equal
{{- if ge .Values.version 1.20 }}     # Greater than or equal
```

---

## 5. Logical Operators (`and`, `or`, `not`)

Combine multiple conditions.

```yaml
{{- if and .Values.persistence.enabled .Values.persistence.existingClaim }}
  useExistingClaim: true
{{- end }}

{{- if or (eq .Values.cloud "aws") (eq .Values.cloud "gcp") }}
  cloudProvider: "external"
{{- end }}

{{- if not .Values.security.disableAuth }}
  authentication: "enabled"
{{- end }}
```

**Complex nested example:**
```yaml
{{- if and (gt .Values.replicas 1) (or (eq .Values.strategy "rolling") (eq .Values.strategy "recreate")) }}
  rollingUpdate:
    maxSurge: 25%
{{- end }}
```

---

## 6. Checking if a Value is in a List (`has`)

Use the `has` function to test membership in an array.

```yaml
{{- $allowedZones := list "us-east-1" "us-west-2" "eu-west-1" }}
{{- if has .Values.region $allowedZones }}
  regionValid: true
{{- else }}
  regionValid: false
{{- end }}
```

**Inline:**
```yaml
{{- if has .Values.storageClass (list "fast" "ssd" "nvme") }}
  storageType: "premium"
{{- else }}
  storageType: "standard"
{{- end }}
```

---

## 7. Checking Map Keys (`hasKey`)

Useful for nested values.

```yaml
{{- if hasKey .Values "tls" }}
  {{- if hasKey .Values.tls "cert" }}
    tlsCert: {{ .Values.tls.cert }}
  {{- end }}
{{- end }}
```

---

## 8. Using `with` (Scope Condition)

`with` executes a block **only if** the value exists and is not empty, and changes the scope (`.`) to that value.

```yaml
{{- with .Values.database }}
  host: {{ .host }}       # Refers to .Values.database.host
  port: {{ .port }}
{{- else }}
  host: "localhost"
  port: 5432
{{- end }}
```

---

## 9. Using `if` inside `range` (Loops)

```yaml
{{- range .Values.services }}
  {{- if .enabled }}
  - name: {{ .name }}
    port: {{ .port }}
  {{- end }}
{{- end }}
```

---

## 10. `if` / `else` in Named Templates (`define`)

**`_helpers.tpl`:**
```yaml
{{- define "mychart.labels" -}}
{{- if .Values.appVersion }}
app: {{ .Values.appName }}
version: {{ .Values.appVersion }}
{{- else }}
app: {{ .Values.appName }}
version: "latest"
{{- end }}
{{- end }}
```

**Usage in your main template:**
```yaml
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
```

---

## 11. One-Line `if` (Inline Conditional)

Use a ternary-like pattern with `default` or `if` in a pipeline.

```yaml
# Using default (simplest)
replicas: {{ .Values.replicas | default 1 }}

# Using a conditional pipeline with `ternary` (Helm 3+)
{{- $enabled := .Values.featureX | default false }}
{{- if $enabled }} feature-x: "active" {{- end }}
```

Helm **does not** have a native ternary operator (`condition ? a : b`), but you can simulate it:

```yaml
# Simulated ternary using if/else inline
volumeSize: {{ if .Values.persistence.size }}{{ .Values.persistence.size }}{{ else }}"10Gi"{{ end }}
```

---

## 12. `if` with `include` (String Output)

```yaml
{{- if include "mychart.isReady" . }}
  ready: "true"
{{- end }}
```

Where `mychart.isReady` is a template that returns a non-empty string if ready.

---

## 13. Using `eq` with Multiple Values (OR pattern)

```yaml
{{- if or (eq .Values.env "prod") (eq .Values.env "production") (eq .Values.env "prd") }}
  envType: "production"
{{- else if or (eq .Values.env "dev") (eq .Values.env "development") }}
  envType: "development"
{{- else }}
  envType: "unknown"
{{- end }}
```

---

## 14. Checking Specific Data Types

```yaml
# Check if a value is a string (kind)
{{- if kindIs "string" .Values.name }}
  nameIsString: true
{{- end }}

# Check if a value is a map
{{- if kindIs "map" .Values.config }}
  configIsMap: true
{{- end }}
```

---

## 15. Full Practical Example (ConfigMap + Deployment)

**`values.yaml`:**
```yaml
replicaCount: 3
image:
  repository: nginx
  tag: 1.21
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
ingress:
  enabled: true
  host: example.com
resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

**`templates/deployment.yaml` (excerpt):**
```yaml
spec:
  replicas: {{ .Values.replicaCount }}
  {{- if .Values.resources }}
  resources:
    {{- if .Values.resources.limits }}
    limits:
      cpu: {{ .Values.resources.limits.cpu }}
      memory: {{ .Values.resources.limits.memory }}
    {{- end }}
    {{- if .Values.resources.requests }}
    requests:
      cpu: {{ .Values.resources.requests.cpu }}
      memory: {{ .Values.resources.requests.memory }}
    {{- end }}
  {{- end }}
```

---

## Important Notes (Helm-specific)

| Syntax | Meaning |
|--------|---------|
| `{{-` (with dash) | Removes whitespace to the left |
| `-}}` (with dash) | Removes whitespace to the right |
| `{{` (no dash) | Preserves whitespace (often leaves blank lines) |
| `.Values` | Root values from `values.yaml` |
| `.Chart` | Metadata about the chart |
| `.Release` | Release-specific metadata (Name, Namespace, etc.) |
| `$` | Global scope (use inside `range`/`with` to access root values) |

---

## Quick Cheat Sheet

```yaml
# Existence
{{- if .Values.foo }}

# Comparison
{{- if eq .Values.mode "prod" }}

# Logical AND
{{- if and .Values.a .Values.b }}

# Logical OR
{{- if or .Values.x .Values.y }}

# Logical NOT
{{- if not .Values.disabled }}

# In list
{{- if has .Values.region (list "us" "eu") }}

# Has key
{{- if hasKey .Values "database" }}

# Numeric
{{- if gt .Values.replicas 1 }}
```

If you need a specific use-case (e.g., nested loops, Helm hooks, or conditionals with `required`), just let me know and I'll expand!