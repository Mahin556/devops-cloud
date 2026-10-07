### References:
- https://medium.com/@ravipatel.it/mastering-kubernetes-secrets-a-comprehensive-guide-b0304818e32b
- https://www.perfectscale.io/blog/kubernetes-secrets
- https://blog.gitguardian.com/how-to-handle-secrets-in-kubernetes/

---

## 🔐 2️⃣ Use RBAC to Control Access to Kubernetes Secrets

Even if your Secrets are encrypted at rest, they can still be **read by anyone with Kubernetes API access** if RBAC is not configured properly.
That’s why RBAC (Role-Based Access Control) is **crucial** — it ensures only authorized identities (users, service accounts, or groups) can read or modify Secrets.

---

### 🧠 What RBAC Does

RBAC allows you to:

* Define **roles** that specify which actions (verbs) are allowed on which **resources**.
* Bind those roles to **subjects** (users, groups, or service accounts).

In the context of Secrets:

* You can **restrict access** so that only specific users or apps can view or modify secrets.
* This follows the **least privilege principle** — every entity gets *only* the access it needs.

---

## 📜 Example: RBAC Policy for Secret Access

### Step 1️⃣ — Create a Role

This `Role` grants **read-only access** (`get`, `list`, `watch`) to secrets **only in the default namespace**.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
```

### Step 2️⃣ — Bind the Role

This `RoleBinding` assigns the above role to a **specific user** (replace `your-username`).

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: default
subjects:
- kind: User
  name: your-username
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

---

### ✅ Verification

To check whether a user has access to Secrets:

```bash
kubectl auth can-i get secrets --as your-username -n default
```

If the user is authorized, you’ll see:

```
yes
```

Otherwise:

```
no
```

---

## 🧩 Role vs ClusterRole

| Type            | Scope            | When to Use                                                                                     |
| --------------- | ---------------- | ----------------------------------------------------------------------------------------------- |
| **Role**        | Namespace-scoped | For granting permissions inside a single namespace (most common for secrets).                   |
| **ClusterRole** | Cluster-scoped   | For managing Secrets across all namespaces (e.g., cluster admin or centralized secret manager). |

If you need to grant cluster-wide secret access:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
```

Bind it using a `ClusterRoleBinding` instead of `RoleBinding`.

---

## 🔒 Security Best Practices with RBAC and Secrets

1️⃣ **Apply Least Privilege Principle**

* Only grant `get` access to Secrets for the workloads or users that truly need it.
* Avoid granting `list` or `watch` unless absolutely necessary (they expose *all* Secrets in a namespace).

2️⃣ **Use ServiceAccounts Instead of Users**

* When workloads (Pods) need access to Secrets, assign them a specific ServiceAccount with a scoped Role.

3️⃣ **Isolate Namespaces**

* Store Secrets in separate namespaces and assign namespace-specific RBAC policies.

4️⃣ **Avoid Wildcards (`*`) in RBAC Rules**

* Example:

  ```yaml
  verbs: ["*"]
  ```

  gives full control (read/write/delete) — a major security risk.

5️⃣ **Regularly Audit Access**

* Run:

  ```bash
  kubectl auth can-i --list --as <user-or-sa>
  ```

  to review effective permissions.

---

## 🧠 Example: Grant Secret Access to a Pod

Here’s a practical scenario where a **Pod** is allowed to read secrets only via a **ServiceAccount**.

### 1️⃣ Create a ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-accessor
  namespace: default
```

### 2️⃣ Bind the Role to It

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-access-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: secret-accessor
  namespace: default
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3️⃣ Use the ServiceAccount in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  serviceAccountName: secret-accessor
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
```

Now this Pod — and only this Pod — can access Secrets in the namespace according to your `secret-reader` Role.

---

## ✅ Summary

| **Concept**                          | **Purpose**                                                  |
| ------------------------------------ | ------------------------------------------------------------ |
| **RBAC (Role-Based Access Control)** | Controls access to cluster resources like Secrets            |
| **Role**                             | Defines allowed actions within a namespace                   |
| **RoleBinding**                      | Binds a Role to a user, group, or ServiceAccount             |
| **ClusterRole/ClusterRoleBinding**   | Same, but across all namespaces                              |
| **Best Practice**                    | Use least privilege, isolate namespaces, and audit regularly |

