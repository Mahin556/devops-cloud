## 🎯 Advanced RBAC: Limiting Access to Specific Keys in a Secret

By default, Kubernetes **RBAC controls access at the resource level**, not at the field/key level inside an object.
That means — out of the box — you can’t use standard RBAC to say:

> “Allow access to `my-secret.password` but not `my-secret.username`.”

However, there are **three production-grade patterns** to achieve this kind of restriction.

---

### 🧩 **Pattern 1: Split Secrets by Sensitivity**

🔹 **What it means:**
Instead of storing multiple keys in one Secret, split them into multiple Secrets — each containing only what a specific workload needs.

#### Example:

```yaml
# Secret for DB username
apiVersion: v1
kind: Secret
metadata:
  name: db-username
  namespace: default
type: Opaque
data:
  username: dXNlcm5hbWU=

---
# Secret for DB password
apiVersion: v1
kind: Secret
metadata:
  name: db-password
  namespace: default
type: Opaque
data:
  password: cGFzc3dvcmQ=
```

Then assign **different Roles**:

```yaml
# Role for password access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: db-password-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-password"]   # 👈 restricts to one Secret only
  verbs: ["get"]
```

✅ **Benefit:**
You can use `resourceNames` in RBAC to lock access to specific Secrets (not keys).
This is the **simplest and most secure** field-level workaround in native Kubernetes.

---

### 🧩 **Pattern 2: External Secret Managers + RBAC Integration**

If you use **external secret stores** (like HashiCorp Vault, AWS Secrets Manager, or Google Secret Manager), you can enforce **key-level policies** there.

#### Example with Vault:

You can define policies such as:

```
path "secret/data/db/password" {
  capabilities = ["read"]
}

path "secret/data/db/username" {
  capabilities = []
}
```

Then integrate it with Kubernetes using the **Vault Agent Injector** or **Secrets Store CSI Driver**, so each Pod gets only the keys it’s authorized for.

✅ **Benefit:**

* True key-level access control.
* Centralized secret auditing and rotation.
* Works across multiple clusters.

---

### 🧩 **Pattern 3: Secrets Store CSI Driver + Key Filtering**

With the **Secrets Store CSI Driver**, you can mount *specific keys* from external secrets directly into Pods.

#### Example:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: db-secret-provider
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "prod/db-secrets"
        objectType: "secretsmanager"
        jmesPath:
          - path: "password"
            objectAlias: "db-password"
```

Then your Pod only gets the `password` key mounted as a file or environment variable — not the rest of the secret.

✅ **Benefit:**

* Pod sees only the keys it needs.
* Ideal for multi-tenant or zero-trust clusters.

---

### ⚖️ Comparison

| Approach                        | Scope                     | Pros                         | Cons                        |
| ------------------------------- | ------------------------- | ---------------------------- | --------------------------- |
| **Split Secrets (native RBAC)** | Kubernetes-only           | Simple, secure, built-in     | More secrets to manage      |
| **Vault / External Store**      | Cross-cluster, enterprise | Key-level ACLs, strong audit | Extra setup and maintenance |
| **CSI Driver Key Filtering**    | Pod-level mounts          | Fine-grained delivery        | Requires CSI setup          |

---

### 🧠 Best Practice Summary

1. **Split sensitive fields into separate Secrets.**
2. **Use `resourceNames` in RBAC** to restrict access to specific Secrets.
3. **Integrate with external Secret managers** for key-level control.
4. **Audit** secret access using `kubectl auth can-i --list` or external logs.
5. **Rotate Secrets frequently** — RBAC doesn’t protect against leaks after access.

### References:
- https://medium.com/@ravipatel.it/mastering-kubernetes-secrets-a-comprehensive-guide-b0304818e32b
- https://www.perfectscale.io/blog/kubernetes-secrets