## Demo 3: Multi-Environment Deployments with Helm

In this demo, we’ll simulate three production-like environments — **dev**, **stage**, and **prod** — using:
* A **single chart**
* **Environment-specific values files**
* **Separate namespaces** per environment

We'll demonstrate how Helm supports:
* Clean multi-environment management
* Release and namespace isolation
* Easier rollout, rollback, and scaling per environment
* Reuse of a single codebase for different configurations

---

### Step 0: Clean Up the Environment

```bash
helm list -A
```

Uninstall previous releases:

```bash
hel, list
helm uninstall <release-name>
```

---

### Step 1: Create Environment Namespaces

Before installing Helm charts into specific namespaces, create them:

```bash
kubectl create ns dev
kubectl create ns stage
kubectl create ns prod
```

---

### Step 2: Ensure Chart Structure Is Production-Ready

If not already done:

```bash
helm create app1-chart
```

Clean up the default templates and use the following:

---

#### `templates/deploy.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-nginx
  namespace: {{ .Values.namespace }}
  labels:
    app: nginx
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: {{ .Release.Name }}-cont
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: 80
```

---

#### `templates/svc.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-nginx
  namespace: {{ .Values.namespace }}
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

> **Note**: We use `.Values.namespace` to inject the namespace dynamically, not hardcoded in Helm commands.

---

### Step 3: Update `Chart.yaml`

```yaml
apiVersion: v2
name: app1-chart
description: Multi-env NGINX web service with environment-specific values
type: application
version: 0.2.0
appVersion: "1.22"
home: https://www.youtube.com/@CloudWithVarJosh
maintainers:
  - name: Varun Joshi
    email: cloudwithvarjosh@gmail.com
keywords:
  - nginx
  - multi-environment
```

### What `appVersion` Should Represent

> In a multi-environment setup, `appVersion` in `Chart.yaml` should always reflect the **production version** of the application.
That’s because:
* The chart is shared across environments — `Chart.yaml` isn’t duplicated.
* Different environments might use different app versions (via `values.yaml`), but the chart's metadata needs to be **stable and meaningful**.
* If `appVersion` were set to a dev or stage version, it could **confuse audit tools, version tracking, and automation pipelines**.

For example:

```yaml
appVersion: "1.22"   # Production NGINX version
```

Even if `dev` is using `nginx:1.23`, the `values-dev.yaml` file will handle that. The `Chart.yaml` still correctly reflects the prod version.


> If you're deploying the same chart to dev, stage, and prod, the `appVersion` in `Chart.yaml` should **always reflect the production app version** — because Helm does not let you customize `Chart.yaml` per release.

This helps maintain clarity, accuracy, and consistency across environments, automation pipelines, and audits.

staging and prod always have n-1 or n-2 version and dev have latest version.

---

### Step 4: Create Environment-Specific `values.yaml` Files

#### `values-dev.yaml`

```yaml
namespace: dev
replicaCount: 1
image:
  repository: nginx
  tag: "1.23"
```

---

#### `values-stage.yaml`

```yaml
namespace: stage
replicaCount: 2
image:
  repository: nginx
  tag: "1.22"
```

---

#### `values-prod.yaml`

```yaml
namespace: prod
replicaCount: 3
image:
  repository: nginx
  tag: "1.22"
```

---


### Step 5: Verify and Deploy to Each Environment

---

### (A) Verify Before You Deploy

When you're using multiple values files (like `values-dev.yaml`), always include them while verifying your Helm chart.

```bash
helm lint ./app1-chart -f ./app1-chart/values-dev.yaml
helm template ./app1-chart -f ./app1-chart/values-dev.yaml
helm template app1-dev ./app1-chart -f ./app1-chart/values-dev.yaml
```

> The last command renders Kubernetes manifests as if you’re doing an actual install (`app1-dev` release + dev values). This is how you catch naming or config issues **before applying anything to your cluster**.

---

### (B) Deploy to Each Environment

We already **inject the namespace through values files** (e.g., `dev`, `stage`, `prod`). That means we **don’t need to pass `--namespace` explicitly** while installing the chart — Helm templates will inject the correct namespace into the manifests.

---

#### Dev

```bash
helm install app1-dev ./app1-chart -f ./app1-chart/values-dev.yaml
```

#### Stage

```bash
helm install app1-stage ./app1-chart -f ./app1-chart/values-stage.yaml
```

#### Prod

```bash
helm install app1-prod ./app1-chart -f ./app1-chart/values-prod.yaml
```

### Important Note: Helm’s Tracking vs Kubernetes Deployment

Helm **sends manifests to the namespace** specified inside the YAML (in `metadata.namespace`), but **Helm itself also tracks the release in a namespace** — the one you specify via `--namespace`, or defaults to `default`.

So if you **don’t explicitly set `--namespace`**, the resources go to `dev`, `stage`, or `prod` (as per values.yaml), but the **Helm release tracking** stays in the `default` namespace.

This is why:

```bash
helm list
```

shows:

```
NAME        NAMESPACE   ...
app1-dev    default     ...
```

Even though your pods and services are in `dev`, `stage`, `prod` namespaces.

---

### Best Practice (Production Style)

To keep things clean and production-aligned:

* Continue specifying `namespace` inside values files (used by Kubernetes)
* Also use `--namespace <env>` in `helm install` so **Helm itself** tracks each release in its corresponding namespace

So the better install command would be:

```bash
helm install app1-dev ./app1-chart -f ./app1-chart/values-dev.yaml --namespace dev
```

If the namespace doesn't exist:

```bash
kubectl create namespace dev
```

> This ensures **both the app** and **Helm's release tracking** are scoped to the same environment. It also makes `helm list`, `helm history`, and `helm rollback` much easier to manage in real-world CI/CD setups.

---


### Step 6: Verify the Deployments

#### List Helm Releases

```bash
helm list -A
```

Expected output:

```
NAME         NAMESPACE  REVISION  STATUS    CHART            APP VERSION
app1-dev     dev        1         deployed  app1-chart-0.2.0  1.22
app1-stage   stage      1         deployed  app1-chart-0.2.0  1.22
app1-prod    prod       1         deployed  app1-chart-0.2.0  1.22
```

> Since we mentioned the production app version (`1.22`) in our `Chart.yaml` under `appVersion`, you see the same reflected under the **APP VERSION** column in the output of `helm list`.

This ties the `Chart.yaml` metadata directly to Helm’s reporting behavior — making it easier for students to understand how this metadata surfaces in real usage.


#### Get Kubernetes Resources per Namespace

```bash
kubectl get deploy,svc -n dev
kubectl get deploy,svc -n stage
kubectl get deploy,svc -n prod
```

Expected:

```
NAME                  READY   UP-TO-DATE   AVAILABLE
app1-dev-nginx        1/1     1            1
app1-stage-nginx      2/2     2            2
app1-prod-nginx       3/3     3            3
```

---

### Step 7: Upgrade Dev Environment Only

```bash
helm upgrade app1-dev ./app1-chart --set image.tag=1.24 --namespace dev
```

Rollback if needed:

```bash
helm rollback app1-dev 1 -n dev
```

---

### Summary

| Env   | Release Name | Namespace | Image      | Replicas |
| ----- | ------------ | --------- | ---------- | -------- |
| dev   | app1-dev     | dev       | nginx:1.23 | 1        |
| stage | app1-stage   | stage     | nginx:1.22 | 2        |
| prod  | app1-prod    | prod      | nginx:1.22 | 3        |

---

### Why Namespaces Matter

* Helm releases are **scoped to namespaces** — which helps isolate configurations and environments
* Avoids resource collisions when the same chart is reused
* Essential for RBAC, network policies, and log segmentation
* You can have multiple `app1-nginx` services — but only if they’re in different namespaces
 