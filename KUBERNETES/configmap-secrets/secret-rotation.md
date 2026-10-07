## 🔹 What Does “Rotating Secrets” Mean?

* **Secret rotation** means replacing an old secret value (like a password, API key, or token) with a new one — **without manual redeploying the whole app**.
* This is crucial for:

  * Security compliance (rotate passwords regularly)
  * Responding to leaks or credential changes
  * Keeping long-running applications secure

In Kubernetes, rotating a secret involves **updating the Secret object** and ensuring **pods pick up the new values**.

---

## 🔹 1. Manual Secret Rotation

### Step-by-step example

#### a) Create a secret

```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=oldpass123
```

#### b) Check its contents

```bash
kubectl get secret db-secret -o yaml
```

You’ll see something like:

```yaml
apiVersion: v1
data:
  password: b2xkcGFzczEyMw==   # base64("oldpass123")
  username: YWRtaW4=
kind: Secret
metadata:
  name: db-secret
type: Opaque
```

#### c) Use it in a pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo
spec:
  containers:
  - name: demo
    image: nginx
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
```

Run it:

```bash
kubectl apply -f pod.yaml
```

#### d) Now, update the secret (manual rotation)

Option 1: Edit directly

```bash
kubectl edit secret db-secret
```

Option 2: Patch/update

```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=newpass456 \
  --dry-run=client -o yaml | kubectl apply -f -
```

This updates the secret in the cluster.

---

### 🔸 But here’s the key point:

> Existing pods that use this secret **will not automatically reload the new values**.

That’s because:

* When Kubernetes injects a secret as an **environment variable**, it copies the secret value **at pod creation time**.
* The environment variable is **static** inside the container process — it won’t change even if the secret object changes later.

So, you need to **restart the pod** to make it pick up the new value.

---

### Step e) Restart the pod to pick up new secret values

```bash
kubectl delete pod secret-demo
kubectl apply -f pod.yaml
```

Now when the container starts, it reads the updated secret.

---

### 🔸 When mounting secrets as **volumes**

If you mount secrets as files inside a pod:

```yaml
volumeMounts:
- name: secret-volume
  mountPath: "/etc/secret"
volumes:
- name: secret-volume
  secret:
    secretName: db-secret
```

then Kubernetes **automatically updates** the files in that mount within **~1 minute** when the secret changes.

However:

* Your application must **re-read** the file to use the new value.
* The app **is not restarted automatically**.

So, you still need a mechanism to restart or reload the app.

---

## 🔹 2. Automated Secret Rotation

To automate the process of refreshing or reloading secrets when they change, you can use **one of three main approaches**:

---

### 🟢 A. Using a Kubernetes Controller or Operator

#### Example: Stakater **Reloader**

Reloader is a popular open-source controller that watches secrets and configmaps.
When it detects a change, it **automatically restarts pods** that use those secrets.

#### Installation:

```bash
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
```

#### Annotate your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx
        envFrom:
        - secretRef:
            name: db-secret
```

When you update `db-secret`, Reloader automatically triggers a rolling restart of `my-app`.

---

### 🟢 B. Using Sidecar Containers

* Run a **sidecar container** in the same pod that watches mounted secret files.
* When the secret file changes (due to Kubernetes updating the volume), the sidecar signals or restarts the main container.

#### Example workflow:

1. Mount the secret to `/etc/secret`.
2. Run a small watcher process (like `configmap-reload` or a custom script) in a sidecar.
3. The sidecar monitors file changes using `inotify`.
4. When it detects an update, it:

   * Sends a signal (like `SIGHUP`) to the main app to reload configuration.
   * Or restarts the container if the app doesn’t support reloads.

This is common in apps like NGINX or Prometheus that can reload configuration dynamically.

---

### 🟢 C. Using External Secret Management Tools

External secret tools handle **secret rotation and injection** automatically from external stores (Vault, AWS Secrets Manager, etc.)

#### Example: External Secrets Operator

* Automatically syncs external secrets into Kubernetes secrets.
* When your Vault/AWS secret changes, it updates the Kubernetes secret — and with Reloader or sidecars, your pods refresh automatically.

#### Example YAML:

```yaml
apiVersion: external-secrets.io/v1alpha1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: db-secret
  data:
  - secretKey: username
    remoteRef:
      key: database/creds
      property: username
  - secretKey: password
    remoteRef:
      key: database/creds
      property: password
```

When the Vault secret rotates, the External Secrets Operator:

* Updates `db-secret`
* Which then triggers a pod restart via Reloader or reload via sidecar

---

## 🔹 3. Verifying Secret Rotation

### Check the new secret data:

```bash
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 --decode
```

### Check pod age and restart:

```bash
kubectl get pods
```

You should see the new pod recreated if automation is working.

---

## 🔹 4. Summary: Behavior by Method

| Mount Method                   | Auto-Reloads?         | Pod Restart Needed?             | Notes                     |
| ------------------------------ | --------------------- | ------------------------------- | ------------------------- |
| Environment Variables          | ❌ No                  | ✅ Yes                           | Static at startup         |
| Volume Mount (File)            | ✅ Yes (within ~1 min) | ❌ No (but app must reread file) | Best for dynamic apps     |
| With Reloader Controller       | ✅ Yes                 | ❌ Auto handled                  | Recommended               |
| With Sidecar Watcher           | ✅ Yes                 | ❌ Auto handled                  | Works for reloadable apps |
| With External Secrets Operator | ✅ Yes                 | ❌ Auto handled                  | Enterprise solution       |

---

## 🔹 Best Practice for Production

* Always **mount secrets as files** (not env vars) when possible.
  → Allows auto-refresh without restarts.
* Combine:

  * `External Secrets Operator` for secret sync
  * `Stakater Reloader` for pod restarts
  * `Encryption at rest` for etcd
  * **RBAC** to restrict access
  * Periodic secret rotation policies
