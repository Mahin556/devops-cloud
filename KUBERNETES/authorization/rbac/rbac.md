### **RBAC (Role-Based Access Control)**

RBAC is the **most widely used** authorization mode in Kubernetes, especially in production environments.

It works by defining **who** (user, group, or service account) can perform **what actions** on **which resources**.

You're absolutely right — that's an important and often overlooked nuance in RBAC.


#### **Key Concepts**

* **Roles**: Define a set of permissions within a **namespace**.
* **RoleBindings**: Associate a **Role *or* ClusterRole** with specific **users**, **groups**, or **service accounts** **within that namespace**.
* **ClusterRoles**: Like roles, but define permissions that can apply **cluster-wide** or be reused across **multiple namespaces**.
* **ClusterRoleBindings**: Bind a **ClusterRole** to **users**, **groups**, or **service accounts** at the **cluster level**, granting access across the entire cluster.

> **Note:** A `RoleBinding` can reference a `ClusterRole`, allowing you to **reuse cluster-defined permissions** in a **specific namespace**. The `ClusterRole`'s rules will only apply **within the namespace** where the `RoleBinding` exists.

---

#### **Example: Give Seema read-only access to Pods in the `default` namespace**

```yaml
# Role: Grants read-only access to Pods in the 'default' namespace
apiVersion: rbac.authorization.k8s.io/v1  # API group for RBAC resources (a named group served under /apis)
kind: Role                                # Namespaced RBAC object that defines permissions
metadata:
  name: pod-reader                        # Name of the Role
  namespace: default                      # Scope: only applies to this namespace
rules:
- apiGroups: [""]                         # Core API group (pods live at /api/v1, so the group is "")
  resources: ["pods"]                     # Type of resource this rule applies to
  verbs: ["get", "watch", "list"]         # Allowed HTTP verbs → maps to API actions like:
                                          # GET /api/v1/namespaces/default/pods
```

```yaml
# Bind the Role to user Seema
# RoleBinding: Assigns the 'pod-reader' Role to user Seema
apiVersion: rbac.authorization.k8s.io/v1  # Same RBAC API group
kind: RoleBinding                         # Binds a Role to a subject (user/group/SA) within the namespace
metadata:
  name: read-pods-binding
  namespace: default                      # RoleBinding is also namespaced; must match the Role's namespace
subjects:
- kind: User                              # Type of subject: User (could also be Group or ServiceAccount)
  name: seema                             # Username (must match what's presented at authentication)
  apiGroup: rbac.authorization.k8s.io     # Required field for all subjects except ServiceAccounts
roleRef:
  kind: Role                              # We're binding a Role (not a ClusterRole)
  name: pod-reader                        # Name of the Role to bind
  apiGroup: rbac.authorization.k8s.io     # The group where the Role is defined
```

> This setup ensures that **Seema** can only **view pods** in the **default** namespace — she cannot delete or modify them.
