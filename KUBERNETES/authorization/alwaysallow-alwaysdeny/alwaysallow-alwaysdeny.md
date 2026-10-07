### **AlwaysAllow / AlwaysDeny Authorization Modes**

These two modes represent the simplest forms of authorization in Kubernetes:

#### **AlwaysAllow**

* **What it does:**
  This mode permits **every request** to the Kubernetes API server, regardless of the user’s identity or the action being requested. Essentially, it **bypasses all authorization checks** and allows all actions.

* **Use-case:**

  * Primarily used for **development, testing, or troubleshooting** purposes where you want to eliminate authorization as a variable.
  * Helpful in initial cluster setup or quick demos when security is not a concern.
  * Not suitable for any environment where access control is required.

* **Limitations:**

  * Offers **no security** whatsoever.
  * Anyone with access to the API can perform any action, including destructive ones.

#### **AlwaysDeny**

* **What it does:**
  This mode **denies every request** to the API server, regardless of user or action. No request will succeed.

* **Use-case:**

  * Mostly useful for **testing failure scenarios** or verifying behavior when authorization fails.
  * Can be used temporarily to **lock down the API** during certain critical maintenance windows.
  * Rarely used in practice because it completely blocks all API access.

* **Limitations:**

  * Effectively **locks out all users and processes**, including administrators.
  * Requires direct intervention (e.g., API server restart with different flags) to revert.

* **How to disable the AlwaysDeny authorization mode in a Kubernetes cluster**
  ```bash
  # Edit the API server manifest
  sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml

  # Find the flag:
  --authorization-mode=AlwaysDeny

  # Replace it with proper modes (example)
  --authorization-mode=Node,RBAC

  # Save and exit
  # Kubelet will automatically restart the API server
  ```

**Summary and Practical Advice**

* Both **AlwaysAllow** and **AlwaysDeny** are **extreme, binary modes** intended only for special cases like testing, demos, or emergency lockdown.
* In **real production clusters**, you should use more granular authorization modes like **RBAC** or **Webhook Authorization**.
* These modes can be enabled or disabled by setting the `--authorization-mode` flag on the Kubernetes API server (e.g., `--authorization-mode=AlwaysAllow`).

---

```bash
==================== AlwaysAllow / AlwaysDeny AUTHORIZATION MODES – PRACTICAL GUIDE ====================

These are the MOST EXTREME authorization modes in Kubernetes.
They exist mainly for:
- Learning
- Debugging
- Emergency control
NOT for real workloads.

======================================================================================

AUTHORIZATION MODES RECAP
------------------------
Authorization decides:
"Is this authenticated identity allowed to perform this action?"

AlwaysAllow and AlwaysDeny answer that question with:
- AlwaysAllow → YES (for everything)
- AlwaysDeny  → NO  (for everything)

No RBAC.
No policies.
No conditions.

======================================================================================

1️⃣ AlwaysAllow AUTHORIZATION MODE
---------------------------------

WHAT IT DOES
------------
- Skips ALL authorization checks
- Every authenticated request is allowed
- RBAC / ABAC / Webhook are bypassed

API SERVER FLAG
---------------
--authorization-mode=AlwaysAllow

WHAT HAPPENS INTERNALLY
-----------------------
Authentication ✔
Authorization ✔ (forced allow)
Admission ✔
Execution ✔

WHO CAN DO WHAT?
----------------
ANY authenticated user can:
✔ Create / delete Pods
✔ Read Secrets
✔ Modify Nodes
✔ Delete namespaces
✔ Destroy the cluster

There is NO access control.

======================================================================================

WHEN TO USE AlwaysAllow
-----------------------
✔ Local demos
✔ Temporary debugging
✔ Verifying authentication problems
✔ Learning Kubernetes API

WHEN NOT TO USE
---------------
❌ Production
❌ Shared clusters
❌ Internet-exposed API servers
❌ Anything with real data

======================================================================================

2️⃣ AlwaysDeny AUTHORIZATION MODE
--------------------------------

WHAT IT DOES
------------
- DENIES every request
- Even admins are blocked
- Even system components are blocked

API SERVER FLAG
---------------
--authorization-mode=AlwaysDeny

WHAT HAPPENS INTERNALLY
-----------------------
Authentication ✔
Authorization ❌ (forced deny)
Admission ❌
Execution ❌

RESULT
------
- kubectl stops working
- Controllers stop
- Scheduler stops
- Control plane becomes unusable

======================================================================================

WHEN WOULD AlwaysDeny EVER BE USED?
-----------------------------------
✔ Testing failure behavior
✔ Academic learning
✔ Emergency API lockdown (VERY RARE)

⚠️ Extremely dangerous if misused

======================================================================================

WHY AlwaysDeny CAN BREAK YOUR CLUSTER
-------------------------------------
Kubernetes components (controller-manager, scheduler, kubelets)
MUST talk to the API server.

AlwaysDeny blocks them all.

Result:
❌ Cluster freeze
❌ Requires manual recovery

======================================================================================

HOW TO RECOVER FROM AlwaysDeny (IMPORTANT)
------------------------------------------

Since kubectl will NOT work, you must:

1) SSH into control-plane node
2) Edit static Pod manifest:
   /etc/kubernetes/manifests/kube-apiserver.yaml

3) Replace:
   --authorization-mode=AlwaysDeny

   With:
   --authorization-mode=Node,RBAC

4) Save file

➡ kubelet auto-restarts kube-apiserver
➡ Cluster recovers

======================================================================================

SAFE MODERN DEFAULT (RECOMMENDED)
--------------------------------
--authorization-mode=Node,RBAC

This gives:
✔ Node-scoped permissions for kubelets
✔ Fine-grained RBAC for users and workloads

======================================================================================

COMPARISON TABLE
----------------

Mode          | Authorization | Security | Use case
--------------|---------------|----------|------------------------
AlwaysAllow  | Allow all     | ❌ None   | Demos / Debug only
AlwaysDeny   | Deny all      | ❌ Locks  | Testing / Emergency
RBAC         | Policy-based  | ✔ Strong | Production
Webhook      | External      | ✔ Strong | Enterprises

======================================================================================

IMPORTANT EXAM & REAL-WORLD NOTES
--------------------------------
- AlwaysAllow does NOT disable authentication
- AlwaysDeny blocks even system components
- These modes are evaluated BEFORE RBAC
- If AlwaysAllow or AlwaysDeny is set ALONE,
  RBAC is ignored

FINAL TAKEAWAY
--------------
AlwaysAllow and AlwaysDeny are NOT security features.
They are CONTROL switches.

Use them only when you:
✔ Know exactly what you are doing
✔ Have console access to recover
✔ Understand the blast radius

======================================================================================
END OF NOTES
======================================================================================
```