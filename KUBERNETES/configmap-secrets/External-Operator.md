EKS-> https://devopscube.com/kubernetes-external-secrets-operator/

# 🔐 How to Use Kubernetes External Secrets Operator (ESO)

The **Kubernetes External Secrets Operator (ESO)** integrates external secrets management systems such as **AWS Secrets Manager**, **HashiCorp Vault**, **Google Secret Manager**, or **OpenBao** with Kubernetes.

With ESO, you can **sync secrets** from these external providers directly into Kubernetes Secrets—allowing you to **manage secrets outside your cluster** while still making them available to workloads inside it.

In this guide, we’ll use **OpenBao** (an open-source, community-driven fork of HashiCorp Vault) as our secret backend.

---

## 🧰 Prerequisites

Before starting, make sure you have:

* A running Kubernetes cluster (e.g., Kind, Minikube, or EKS).
* `kubectl` and `helm` installed and configured.
* The **OpenBao CLI (`bao`)** installed.

---

## ⚙️ Step 1: Install External Secrets Operator (ESO)

The easiest way to install ESO is via **Helm**:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets
```

✅ **Expected Output:**

```
external-secrets has been deployed successfully in namespace default!
```

Verify the pods:

```bash
kubectl get pods | grep -i external-secrets
```

✅ **Example Output:**

```
external-secrets-55dbcddd4-qzmwm                    1/1     Running   0   91s
external-secrets-cert-controller-86859999ff-4zklh   1/1     Running   0   91s
external-secrets-webhook-56f4f9b965-dfsdp           1/1     Running   0   91s
```

---

## 🔐 Step 2: Install OpenBao (Vault-Compatible Secret Backend)

Add the Helm repository and install OpenBao in its own namespace:

```bash
helm repo add openbao https://openbao.github.io/openbao-helm
helm repo update

kubectl create namespace openbao
helm install openbao openbao/openbao --namespace openbao --set server.dev.enabled=true
```

Verify that OpenBao is running:

```bash
kubectl get pods -n openbao
```

✅ **Example Output:**

```
openbao-0                                 1/1     Running   0   57s
openbao-agent-injector-5778f8b977-6gr7p   1/1     Running   0   57s
```

---

## 🌐 Step 3: Configure and Access OpenBao

Port-forward to access the OpenBao service locally:

```bash
kubectl -n openbao port-forward svc/openbao 8200:8200 &
```

Set the Vault (Bao) environment variable:

```bash
export VAULT_TOKEN='root'
```

Check connectivity:

```bash
bao status
```

✅ **Expected Output:**

```
Seal Type       shamir
Initialized     true
Sealed          false
Storage Type    inmem
Version         2.1.1
```

---

## 🗝️ Step 4: Create Secrets in OpenBao

Create a demo secret inside OpenBao:

```bash
bao kv put secret/demo-secret username="demo-user" password="demo-pass"
```

Verify it:

```bash
bao kv get secret/demo-secret
```

✅ **Example Output:**

```
====== Data ======
Key         Value
---         -----
username    demo-user
password    demo-pass
```

---

## 🧩 Step 5: Configure ESO to Use OpenBao

You’ll need to define a **ClusterSecretStore** and a Kubernetes **Secret** containing the Vault token.

Create a file named `secretstore.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: openbao-backend
spec:
  provider:
    vault:
      server: "http://openbao.openbao:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: openbao-token
          key: token
---
apiVersion: v1
kind: Secret
metadata:
  name: openbao-token
type: Opaque
stringData:
  token: "root"
```

Apply it:

```bash
kubectl apply -f secretstore.yaml
```

✅ **Expected Output:**

```
clustersecretstore.external-secrets.io/openbao-backend created
secret/openbao-token created
```

---

## 🧾 Step 6: Create External Secrets from OpenBao Data

Create an `ExternalSecret` definition (`demo-external-secret.yaml`) to fetch the demo-secret from OpenBao:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: demo-secret
spec:
  refreshInterval: "15s"
  secretStoreRef:
    name: openbao-backend
    kind: ClusterSecretStore
  target:
    name: demo-secret
  data:
    - secretKey: username
      remoteRef:
        key: demo-secret
        property: username
    - secretKey: password
      remoteRef:
        key: demo-secret
        property: password
```

Apply the secret:

```bash
kubectl apply -f demo-external-secret.yaml
```

---

## 🧱 Step 7: Create a Nested Secret Example

Let’s store another secret under a nested path:

```bash
bao kv put secret/dev/db-secret username="db-user" password="db-pass"
```

Then create another ExternalSecret definition (`dbextsecret.yaml`):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
spec:
  refreshInterval: "15s"
  secretStoreRef:
    name: openbao-backend
    kind: ClusterSecretStore
  target:
    name: dev
  data:
    - secretKey: username
      remoteRef:
        key: dev/db-secret
        property: username
    - secretKey: password
      remoteRef:
        key: dev/db-secret
        property: password
```

Apply it:

```bash
kubectl apply -f dbextsecret.yaml
```

✅ **Expected Output:**

```
externalsecret.external-secrets.io/db-secret created
```

---

## 🔍 Step 8: Verify Secrets in Kubernetes

List all Secrets:

```bash
kubectl get secrets
```

✅ **Example Output:**

```
NAME               TYPE     DATA   AGE
demo-secret        Opaque   2      9m
dev                Opaque   2      27s
openbao-token      Opaque   1      9m
```

View and decode a secret value:

```bash
kubectl get secret demo-secret -o jsonpath='{.data.username}' | base64 -d
# Output: demo-user

kubectl get secret demo-secret -o jsonpath='{.data.password}' | base64 -d
# Output: demo-pass
```

Similarly, for the nested one:

```bash
kubectl get secret dev -o jsonpath='{.data.username}' | base64 -d
# Output: db-user

kubectl get secret dev -o jsonpath='{.data.password}' | base64 -d
# Output: db-pass
```

---

## ✅ Summary

| Component                           | Purpose                                                          |
| ----------------------------------- | ---------------------------------------------------------------- |
| **External Secrets Operator (ESO)** | Syncs secrets from external backends into Kubernetes             |
| **OpenBao**                         | Vault-compatible secret backend used for secure secret storage   |
| **ClusterSecretStore**              | Defines how ESO connects to the external backend                 |
| **ExternalSecret**                  | Defines which secret to pull and where to store it in Kubernetes |
| **Target Secret**                   | The final Kubernetes Secret generated from the external data     |

---

## 🧠 Best Practices

* Use **ClusterSecretStore** for cluster-wide access or **SecretStore** for namespace-level scope.
* Use **Vault roles and policies** instead of root tokens in production.
* Rotate credentials regularly in the external secret manager.
* Enable **audit logs and encryption** in your secret manager.
* Use GitOps (e.g., ArgoCD or Flux) to manage ESO manifests securely.

| **Alternative**                              | **Description**                                          | **Benefits**                        |
| -------------------------------------------- | -------------------------------------------------------- | ----------------------------------- |
| **HashiCorp Vault**                          | Centralized secret management with fine-grained policies | Dynamic secrets, strong audit       |
| **AWS Secrets Manager / GCP Secret Manager** | Cloud-managed secret stores                              | Key-level IAM, rotation, encryption |
| **Secrets Store CSI Driver**                 | Mounts secrets from external providers as volumes        | Automatic sync and key filtering    |


### References:
- https://spacelift.io/blog/kubernetes-secrets
- https://medium.com/@ravipatel.it/mastering-kubernetes-secrets-a-comprehensive-guide-b0304818e32b