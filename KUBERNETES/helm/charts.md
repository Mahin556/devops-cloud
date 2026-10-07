## What is Chart.yaml?
- It is the **metadata file** for a Helm chart
- Every Helm chart **must have** this file
- Tells Helm about the chart — its name, version, type, etc.

---

## Line by Line Explanation

### `apiVersion: v2`
- Defines which **Helm API version** this chart uses
- `v2` → Helm 3 *(current standard)*
- `v1` → Helm 2 *(old, deprecated)*
- **Always use `v2`** for new charts

---

### `name: sample-chart`
- The **name of your Helm chart**
- Must be **lowercase**, no spaces (use hyphens)
- Should match your **folder name**
- Best practices:
```yaml
# Good
name: my-app
name: sonarqube-chart
name: payment-service

# Bad
name: MyApp          # no uppercase
name: my app         # no spaces
name: my_app         # avoid underscores
```

---

### `description: A Helm chart for Kubernetes`
- A **short description** of what the chart does
- Best practice — be specific:
```yaml
# Bad
description: A Helm chart for Kubernetes

# Good
description: Helm chart for deploying SonarQube with PostgreSQL on EKS
```

---

### `type: application`
Two types exist:

| Type | Description |
|---|---|
| **application** | A deployable chart — creates actual K8s resources (pods, services, etc.) |
| **library** | Reusable utilities/functions for other charts — **cannot be deployed alone** |

- For most use cases → always use `application`
- Use `library` only when creating **shared/helper charts** for other developers

---

### `version: 0.1.0`
- This is the **chart version** — version of the Helm chart itself
- Follows **Semantic Versioning (SemVer)**: `MAJOR.MINOR.PATCH`

```
0  .  1  .  0
↑     ↑     ↑
MAJOR MINOR PATCH
```

| Part | When to increment | Example |
|---|---|---|
| **MAJOR** | Breaking changes | `0.1.0` → `1.0.0` |
| **MINOR** | New features added | `0.1.0` → `0.2.0` |
| **PATCH** | Bug fixes | `0.1.0` → `0.1.1` |

**Best practices:**
```yaml
# Starting a new chart
version: 0.1.0

# Added a new feature (e.g., added ingress support)
version: 0.2.0

# Fixed a bug in templates
version: 0.1.1

# Major redesign / breaking change
version: 1.0.0
```

- **Important** — increment this every time you modify chart templates
- Used by Helm to track chart changes

---

### `appVersion: "1.16.0"`
- This is the **application version** — version of the actual app being deployed
- For example:
  - If deploying **SonarQube 10.8** → `appVersion: "10.8"`
  - If deploying **Nginx 1.25** → `appVersion: "1.25"`
- **Always wrap in quotes** as recommended
- Does **not** need to follow SemVer — just match the app's release version

---

## chart version vs appVersion

```
version: 0.1.0        →   Version of the HELM CHART
appVersion: "1.16.0"  →   Version of the APPLICATION inside the chart
```

**Real world example:**
```yaml
# You deployed SonarQube 10.8 using your chart version 1.2.0
version: 1.2.0
appVersion: "10.8"

# You fixed a bug in your helm templates but app version is same
version: 1.2.1          # chart version bumped
appVersion: "10.8"      # app version stays same

# SonarQube releases 10.9, you update chart to support it
version: 1.3.0          # chart version bumped (new feature)
appVersion: "10.9"      # app version updated
```

---

## Complete Best Practice Chart.yaml
```yaml
apiVersion: v2

name: sonarqube-chart
description: Helm chart for deploying SonarQube with PostgreSQL backend on EKS

# application = deployable, library = reusable utilities only
type: application

# Chart version — increment on every chart change (SemVer)
# MAJOR.MINOR.PATCH
version: 1.0.0

# Application version — match the actual app release version
# Always use quotes
appVersion: "10.8"

# Optional but recommended fields below

# Minimum Helm version required
kubeVersion: ">=1.21.0"

keywords:
  - sonarqube
  - devops
  - code-quality
  - sast

maintainers:
  - name: Your Name
    email: you@example.com

dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
```

---

## Summary

| Field | Purpose | Who changes it |
|---|---|---|
| `apiVersion` | Helm API version | Never (always v2) |
| `name` | Chart name | Once at creation |
| `description` | What chart does | Rarely |
| `type` | application or library | Once at creation |
| `version` | Chart version | Every chart change |
| `appVersion` | App version | When app updates |