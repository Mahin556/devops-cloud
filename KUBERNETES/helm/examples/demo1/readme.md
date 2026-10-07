## Demo 1: Writing Your Own Helm Chart from Scratch

### Objective

In this first Helm demo, we will deploy **nginx** as a NodePort service using a custom Helm chart.

Our goal is to:

* Scaffold a Helm chart
* Write plain Kubernetes YAMLs (without templating)
* Gradually introduce templating using Helm's built-in objects
* Test using `lint`, `template`, and `--dry-run`
* Install and verify the chart
* Understand how Helm handles releases and variables

---

## Step 1: Scaffold Helm Directory

Start by creating a new Helm chart using:

```bash
helm create app1-chart
```

This generates a directory structure like:

```
app1-chart/
├── charts/
├── templates/
├── Chart.yaml
└── values.yaml
```

We’ll remove all auto-generated templates and start from scratch.

---

## Step 2: Add Basic (Plain) YAMLs

Delete everything inside the `templates/` folder and create two files:

* `deploy.yaml`
* `svc.yaml`

We'll start with plain YAML — no templating yet — just like in raw Kubernetes. This helps you clearly understand what Helm does behind the scenes.

---

### `deploy.yaml` (Plain)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.22
          ports:
            - containerPort: 80
```

---

### `svc.yaml` (Plain)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

---

### Substep: This Chart Is Already Installable — But Not Reusable

At this stage, we haven't introduced any Helm templating yet — but the chart **is still valid** and **can be installed** using:

```bash
helm install app1 ./app1-chart
```

This command will create the following Kubernetes resources:

* A Deployment named `nginx-deploy`
* A Service named `nginx-svc`

Now, suppose you try to install the same chart again for testing purposes:

```bash
helm install app1-test ./app1-chart
```

This command will **fail** with an error like:

```
Error: INSTALLATION FAILED: rendered manifests contain a resource that already exists.
```

> Why? Because the Deployment (`nginx-deploy`) and Service (`nginx-svc`) already exist in the cluster — Helm does not automatically change resource names based on the release name unless we tell it to.

---

### Lesson

To support **multiple releases** from the same chart (e.g., `app1-prod`, `app1-test`, `app1-staging`), we must **templatize the resource names** by prefixing them with the Helm **release name**.
This improves:
* Reusability of the chart
* Clarity in cluster resources (`app1-prod-nginx`, `app1-test-nginx`)
* Easier troubleshooting and rollbacks per release

We’ll do this in the next step by using:

```yaml
metadata:
  name: {{ .Release.Name }}-nginx
```


---

## Step 3: Introduce Helm Templating

We'll now make our manifests reusable by templatizing key fields like:
* release name
* replica count
* image tag and repository

### Updated `deploy.yaml` (Templatized)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-nginx  # Release-aware name
  labels:
    app: nginx
spec:
  replicas: {{ .Values.replicaCount }}  # From values.yaml
  selector:
    matchLabels:
      app: {{ .Release.Name }}-pods
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-pods
    spec:
      containers:
        - name: nginx
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: 80
```

### Updated `svc.yaml` (Templatized)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-nginx
spec:
  type: NodePort
  selector:
    app: {{ .Release.Name }}-pods
  ports:
    - port: 80
      targetPort: 80
```

---

## Step 4: Update `values.yaml`

This file defines variables consumed in templates.

```yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.22"
```

> Think of `values.yaml` as your input file for all configuration. It acts like the central config layer of your Helm chart.

---

## Step 5: Update `Chart.yaml`

Update the metadata in `Chart.yaml`:

```yaml
apiVersion: v2
name: app1-chart
description: A Helm chart to deploy nginx using NodePort service
type: application
version: 0.1.0
appVersion: "1.22"
home: https://www.youtube.com/@CloudWithVarJosh
maintainers:
  - name: Varun Joshi
    email: cloudwithvarjosh@gmail.com
keywords:
  - nginx
  - demo
  - kubernetes
  - helm
```

---

## Step 6: Understanding Helm Templating

#### Understanding `{{ .Release.Name }}` in Helm

In Helm templates, `{{ .Release.Name }}` is used to dynamically insert the name of the Helm release into your Kubernetes manifest.

* `{{ ... }}` is Helm’s way of saying: “evaluate this expression”
* The leading `.` refers to the current template context
* `.Release.Name` accesses the name of the release (e.g., `app1-prod`)

So if your release name is `app1`, this line:

```yaml
metadata:
  name: {{ .Release.Name }}-nginx-deploy
```

will render as:

```yaml
metadata:
  name: app1-nginx-deploy
```
This makes your templates reusable and uniquely tied to each release — which is especially useful in multi-environment setups.

---

Helm exposes several built-in objects. Here are the most common:

### `.Values` – User-defined inputs (from `values.yaml`)

* `.Values.replicaCount`, `.Values.image.repository`
* You control these
* Always use in production

### `.Release` – Information about the release

* `.Release.Name`: release name (e.g. `app1-prod`)
* `.Release.Namespace`: namespace of release
* `.Release.Revision`: revision number (incremented on upgrade/rollback)
* `.Release.IsInstall`, `.Release.IsUpgrade`: helpful for conditional logic

### `.Chart` – Metadata from `Chart.yaml`

* `.Chart.Name`, `.Chart.Version`, `.Chart.AppVersion`

### `.Capabilities` – Info about Kubernetes cluster

* `.Capabilities.KubeVersion.Version` — useful for conditional logic
* `.Capabilities.APIVersions.Has "apps/v1"` — to check resource availability

> Naming conventions:

* You define `.Values`, hence lowercase
* Others (built-ins) follow PascalCase (e.g., `.Release.Name`)

---

## Step 7: Helm Verification Commands

### Lint the Chart

```bash
helm lint ./app1-chart
```

Checks basic structure and naming.

### Render Templates

```bash
helm template ./app1-chart
helm template app1 ./app1-chart
```

Add `--debug` for insights:

```bash
helm template app1 ./app1-chart --debug
```

### Run with Dry-Run

```bash
helm install app1 ./app1-chart --dry-run
```

Validates final manifests against Kubernetes schema (not just YAML correctness).

| Command                  | What it does                                                                             |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| `helm lint`              | Validates structure of the chart directory + YAML syntax                                 |
| `helm template`          | Renders templates into final manifests — but doesn't simulate a release                  |
| `helm install --dry-run` | Renders templates **and** simulates a Helm release install, without touching the cluster |


---

## Step 8: Install the Chart

```bash
helm install app1 ./app1-chart
```

### Helm Verification

```bash
helm list

#You see helm version and chart version === idealy they must be same

helm status app1
helm history app1
```

### Kubernetes Verification

```bash
kubectl get deploy,svc
kubectl get pods
```

---

## Uninstall the Chart

```bash
helm uninstall app1
```

---

## Final Notes

### Why Helm Templating Matters

If you tried installing the same chart twice:

```bash
helm install app1 ./app1-chart
helm install app1 ./app1-chart  # Fails: resource already exists
```

Helm will fail unless you templatize names using `{{ .Release.Name }}`.

### Multiple Releases from the Same Chart

You can reuse the same chart to create different releases:

```bash
helm install app1-prod ./app1-chart
helm install app1-prod-test ./app1-chart
```

Each release:

* Has its own lifecycle (install/upgrade/rollback)
* Maintains its own `values.yaml`
* Will be tracked independently by Helm

```bash
helm history app1-prod-test
```

This is especially useful for **hotfix testing**, **blue/green deployments**, or **multi-tenant apps**.
