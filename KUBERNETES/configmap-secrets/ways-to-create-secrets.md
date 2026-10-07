# 🧩 Ways to Create Kubernetes Secrets

In Kubernetes, **Secrets** are objects designed to securely store sensitive information such as passwords, tokens, and SSH keys. There are multiple ways to create and manage Secrets, depending on your workflow.

---

## ⚙️ Overview

You can create Kubernetes Secrets using one of the following methods:

1. **Using `kubectl`**
2. **Using a YAML manifest file**
3. **Using a generator like Kustomize**

### 🔑 Key Points

* Secrets are created **outside of pods** — a Secret must exist before a Pod can use it.
* Secrets are stored in **etcd**, the Kubernetes data store, managed by the control plane.
* When creating Secrets, you can use:

  * `data` → requires Base64-encoded values
  * `stringData` → allows plain-text values (Kubernetes encodes them automatically)
* The **maximum Secret size** is **1 MB**.
* You can make Secrets **immutable** by adding `immutable: true` to prevent accidental updates.
* Secrets can be **injected into Pods** as:

  * Environment variables
  * Volume mounts
  * `imagePullSecrets` for container registries

---

## 🧰 Prerequisites

Before creating Secrets, ensure that:

* You have access to a running **Kubernetes cluster** (for example, via Minikube).
* The **kubectl CLI** is configured to communicate with your cluster.

Let’s also create a namespace to isolate our demo resources:

```bash
kubectl create namespace secrets-demo
```

---

## 1️⃣ Creating Secrets Using `kubectl`

The `kubectl create secret` command allows you to generate Secrets directly from your terminal.

There are two main ways to provide Secret data:

1. **From a file** → `--from-file=<filename>`
2. **From a literal value** → `--from-literal=<key>=<value>`

> ⚠️ When using `--from-literal`, escape special characters such as `$`, `\`, `*`, `=`, or `!` using single quotes.

While kubectl is a quick way to create various types of Secrets, it’s best suited for development and testing.
In production environments, consider using declarative manifest files or Kustomize — these approaches provide better security, traceability, and version control.

### Example: Create Secrets from Files

First, create two files containing credentials:

```bash
echo -n 'admin' > username.txt
echo -n 'password' > password.txt
```

Verify the file contents:

```bash
cat username.txt
cat password.txt
```

Now, create the Secret:

```bash
kubectl create secret generic database-credentials \
  --from-file=username.txt \
  --from-file=password.txt \
  --namespace=secrets-demo
```

By default, the key names will be the filenames (`username.txt` and `password.txt`).
To define custom key names:

```bash
kubectl create secret generic database-credentials \
  --from-file=username=username.txt \
  --from-file=password=password.txt \
  --namespace=secrets-demo

kubectl create secret generic my-secret \
  --from-file=ssh-privatekey=~/.ssh/id_rsa

```

Verify that the Secret was created successfully:

```bash
kubectl -n secrets-demo get secrets
```

From string literals:
```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpassword
```

---

## 2️⃣ Creating Secrets from a YAML Manifest File

You can also define Secrets declaratively in a YAML manifest file.

### Option A — Using the `data` Field (Base64 Encoded)

First, encode your values:

```bash
echo -n 'admin' | base64
# Output: YWRtaW4=

echo -n 'password' | base64
# Output: cGFzc3dvcmQ=
```

Now create a file named `demo-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: demo-secret
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
```

Apply the manifest:

```bash
kubectl -n secrets-demo apply -f demo-secret.yaml
```

---

### Option B — Using the `stringData` Field (Plain Text)

Alternatively, you can use the `stringData` field, which automatically encodes values:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: demo-secret
type: Opaque
stringData:
  username: admin
  password: password
```

Apply it with the same command:

```bash
kubectl -n secrets-demo apply -f demo-secret.yaml
```

---

## 3️⃣ Creating Secrets Using Kustomize

Kustomize allows you to generate Secrets dynamically using a `kustomization.yaml` file.
This is ideal for automating deployments or managing multiple environments.

### Option A — From Files

```yaml
secretGenerator:
- name: database-credentials
  files:
  - username.txt
  - password.txt
```

### Option B — From Literal Values

```yaml
secretGenerator:
- name: database-credentials
  literals:
  - username=admin
  - password=password
```

### Option C — From an Environment File

```yaml
secretGenerator:
- name: database-credentials
  envs:
  - .env.secret
```

Then, apply it using:

```bash
kubectl -n secrets-demo apply -k .
```

Kustomize will automatically generate the Secret without requiring manual Base64 encoding.

---

## ✅ Summary

| Method                         | Description                                         | Encoding Required | Example Command                |
| ------------------------------ | --------------------------------------------------- | ----------------- | ------------------------------ |
| **kubectl (file)**             | Reads secrets from local files                      | No                | `--from-file=username.txt`     |
| **kubectl (literal)**          | Passes key-value pairs directly                     | No                | `--from-literal=password=1234` |
| **YAML Manifest (data)**       | Uses Base64-encoded values                          | Yes               | Define in `data:` field        |
| **YAML Manifest (stringData)** | Uses plain-text values                              | No                | Define in `stringData:` field  |
| **Kustomize**                  | Uses `secretGenerator` for files, literals, or envs | No                | `kubectl apply -k .`           |

---

## 🚀 Next Steps

After creating your Secrets, you can:

* **Inspect** them with `kubectl describe secret <name>`
* **Decode** them with `kubectl get secret <name> -o jsonpath='{.data.key}' | base64 --decode`
* **Mount** them as volumes or **inject** them as environment variables in Pods

> 🔐 For production environments, remember to **enable encryption at rest** in your API server and use proper **RBAC** rules to control access to Secrets.


### References:
- https://spacelift.io/blog/kubernetes-secrets
- https://www.geeksforgeeks.org/devops/kubernetes-secrets/