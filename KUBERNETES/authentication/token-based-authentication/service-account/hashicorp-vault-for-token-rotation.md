Below is a **complete, production-grade, end-to-end Vault-based Kubernetes ServiceAccount token rotation setup**, including:

* Vault configuration
* Kubernetes auth method
* Role configuration
* Vault Agent token auto-renewal
* External application integration
* Full YAML + HCL + CLI

This is a **professional-level setup** used in enterprises.

---

# 🚀 **GOAL**

External applications (Jenkins, GitHub Actions, Terraform, Ansible, CI/CD tools) authenticate to Kubernetes **via Vault**, and Vault automatically:

✔ Generates short-lived Kubernetes tokens
✔ Rotates tokens automatically
✔ Prevents storing static tokens
✔ Removes secrets from apps

---

# 🔥 **HIGH-LEVEL FLOW**

```
External App → Vault → Kubernetes TokenRequest API → Short-lived SA token → External App
```

Vault handles:

* authentication
* token request
* token renewal
* token expiration
* secure delivery

---

# 🟩 **STEP 1 — Enable Kubernetes Auth in Vault**

On your Vault server:

```
vault auth enable kubernetes
```

---

# 🟩 **STEP 2 — Configure Vault to Communicate With Kubernetes**

You need:

* Kubernetes API server URL
* Token reviewer JWT
* Cluster CA certificate

Get the reviewer token:

```
kubectl -n kube-system get secret \
$(kubectl -n kube-system get sa default -o jsonpath='{.secrets[0].name}') \
-o jsonpath='{.data.token}' | base64 --decode
```

Get CA:

```
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > ca.crt
```

Now configure Vault:

```
vault write auth/kubernetes/config \
  kubernetes_host="https://<K8S-API>:6443" \
  token_reviewer_jwt="<REVIEWER-TOKEN>" \
  kubernetes_ca_cert=@ca.crt
```

---

# 🟩 **STEP 3 — Create a Kubernetes ServiceAccount to Use**

Example:

```
kubectl create namespace devops-tools

kubectl create serviceaccount vault-sa -n devops-tools
```

Create RBAC:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-sa-binding
subjects:
- kind: ServiceAccount
  name: vault-sa
  namespace: devops-tools
roleRef:
  kind: ClusterRole
  name: cluster-admin   # For demo, NOT recommended!
  apiGroup: rbac.authorization.k8s.io
```

---

# 🟩 **STEP 4 — Create a Vault Role That Issues Kubernetes Tokens**

Inside Vault:

```
vault write auth/kubernetes/role/devops-role \
  bound_service_account_names="vault-sa" \
  bound_service_account_namespaces="devops-tools" \
  ttl="10m" \
  max_ttl="30m" \
  policies="k8s-policy"
```

---

# 🟩 **STEP 5 — Create Vault Policy Allowing Kubernetes Token Issuance**

Create `k8s-policy.hcl`:

```hcl
path "auth/kubernetes/login" {
  capabilities = ["create"]
}

path "kubernetes/token/*" {
  capabilities = ["create", "update"]
}
```

Apply:

```
vault policy write k8s-policy k8s-policy.hcl
```

---

# 🟩 **STEP 6 — Enable Kubernetes Secrets Engine in Vault**

```
vault secrets enable kubernetes
```

Configure the secrets engine to use ServiceAccount:

```
vault write kubernetes/config \
  token_reviewer_jwt="$(kubectl create token vault-sa -n devops-tools)" \
  kubernetes_host="https://<K8S-API>" \
  kubernetes_ca_cert=@ca.crt
```

---

# 🟩 **STEP 7 — Create a Vault Role to Issue Short-Lived Tokens**

```
vault write kubernetes/role/devops-sa-role \
  service_account_name="vault-sa" \
  service_account_namespace="devops-tools" \
  expiration_seconds=600
```

This means:

* Vault can issue short-lived Kubernetes tokens
* These tokens are valid for 10 minutes
* They belong to the `vault-sa` ServiceAccount

---

# 🟩 **STEP 8 — External Application Requests Token From Vault**

Use Vault’s token:

```
vault write kubernetes/token/devops-sa-role
```

Output example:

```json
{
  "request_id": "e9aec...",
  "data": {
    "token": "eyJhbGciOiJSUzI1NiIsInR...",
    "expiration": "2025-01-27T12:34:56Z"
  }
}
```

THIS token is:

* A Kubernetes short-lived token
* Signed by Kubernetes
* Scoped to SA + RBAC
* Auto-expires
* Renewable

Your external tool can now use it:

```
Authorization: Bearer <token>
```

---

# 🟩 **STEP 9 — Enable Vault Agent for Automatic Token Rotation**

Create `vault-agent.hcl`:

```hcl
exit_after_auth = false
pid_file = "./pidfile"

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "devops-role"
    }
  }

  sink "file" {
    config = {
      path = "/opt/app/k8s-token.txt"
    }
  }
}

template {
  destination = "/opt/app/k8s-token.txt"
  contents = <<EOF
{{ with secret "kubernetes/token/devops-sa-role" }}
{{ .Data.token }}
{{ end }}
EOF
}
```

Run Vault agent:

```
vault agent -config=vault-agent.hcl
```

Vault agent will:

✔ Authenticate to Vault
✔ Automatically request new tokens
✔ Auto-rotate every `ttl`
✔ Save tokens to a file for your app
✔ Never store any static credentials

---

# 🟩 **STEP 10 — External Application Uses the Auto-Rotated Token**

Your app simply reads:

```
/opt/app/k8s-token.txt
```

And uses:

```
curl -H "Authorization: Bearer $(cat /opt/app/k8s-token.txt)" \
  https://<api>/api/v1/pods
```

The app doesn’t care about rotation.
Vault Agent keeps the token fresh forever.

---

# ⭐ **FINAL ARCHITECTURE**

```
Kubernetes ←→ Vault Kubernetes Auth

ServiceAccount (vault-sa)
      ↓
TokenRequest API ←→ Vault Kubernetes Secrets Engine
      ↓
Vault Agent (auto-renew)
      ↓
Rotated token file
      ↓
External App uses token
```

---

# ⭐ **BENEFITS OF VAULT-BASED TOKEN ROTATION**

✔ No static tokens
✔ No long-lived ServiceAccount tokens
✔ No K8s Secrets holding tokens
✔ Real short-lived, auto-expiring JWTs
✔ Tokens auto-rotated by Vault Agent
✔ External apps never store long-term keys
✔ Secure, enterprise-grade solution

---

If you want, I can also provide:

✔ Full architecture diagram (ASCII or image)
✔ Jenkins / GitHub Actions / Terraform examples
✔ Vault Helm chart deployment for Kubernetes
✔ Auto-rotation systemd service
✔ Step-by-step troubleshooting guide

Just tell me!
