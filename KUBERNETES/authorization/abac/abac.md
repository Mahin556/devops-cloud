### **ABAC (Attribute-Based Access Control)**

ABAC authorizes requests based on a set of **attribute-based rules** defined in a **JSON policy file**. It evaluates access based on attributes such as the user, verb, resource type, and namespace.

**Key Concepts:**

* Policies are defined in a static **JSON file**.
* Each rule explicitly describes **who** can do **what** on **which resource**, similar in concept to RBAC but with no roles or bindings.
* Rules are flat—there’s no hierarchy or grouping.
* **Any change** (addition, modification, or deletion) in the JSON file **requires the API server to be restarted** for the changes to take effect.
* Considered **deprecated** and **not suitable** for production environments.

**Example ABAC Policy File (`abac-policy.json`):**

```json
[
  {
    "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
    "kind": "Policy",
    "spec": {
      "user": "seema",
      "namespace": "default",
      "resource": "pods",
      "verb": "get"
    }
  },
  {
    "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
    "kind": "Policy",
    "spec": {
      "user": "seema",
      "namespace": "default",
      "resource": "pods",
      "verb": "list"
    }
  }
]
```

This allows user `seema` to `get` and `list` Pods in the `default` namespace.

**To enable ABAC:**

Start the API server with:

```bash
kube-apiserver \
  --authorization-mode=ABAC \
  --authorization-policy-file=/etc/kubernetes/abac-policy.json
```

> 🔴 **Note:** Any change to the JSON file requires an API server restart for the updated rules to take effect.


**Note:** ABAC is mainly useful for historical context or academic purposes. **RBAC is the recommended and actively supported authorization mode in Kubernetes today.**

```bash
==================== ABAC (Attribute-Based Access Control) – COMPLETE PRACTICAL DEMO ====================

⚠️ IMPORTANT CONTEXT
--------------------
- ABAC is DEPRECATED
- NOT recommended for production
- Still useful to understand:
  - Kubernetes authorization evolution
  - Why RBAC exists
  - Legacy clusters / exams / interviews

This demo is for LEARNING ONLY.

===============================================================================================

GOAL OF THIS PRACTICAL
----------------------
- Enable ABAC authorization
- Write ABAC policy rules
- Authenticate as a user
- Prove allowed vs denied actions
- Understand why ABAC is painful to operate

===============================================================================================

PREREQUISITES
-------------
- Single-node cluster (kind / kubeadm / minikube)
- Access to API server flags
- Cluster-admin / root access
- Ability to restart kube-apiserver

⚠️ This is easiest on:
- kubeadm cluster
- kind cluster
- minikube

===============================================================================================

STEP 1: CREATE ABAC POLICY FILE
--------------------------------
Create the policy file on the control-plane node.

File: /etc/kubernetes/abac-policy.json

[
  {
    "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
    "kind": "Policy",
    "spec": {
      "user": "seema",
      "namespace": "default",
      "resource": "pods",
      "verb": "get"
    }
  },
  {
    "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
    "kind": "Policy",
    "spec": {
      "user": "seema",
      "namespace": "default",
      "resource": "pods",
      "verb": "list"
    }
  }
]

MEANING:
- User: seema
- Namespace: default
- Resource: pods
- Allowed verbs: get, list

===============================================================================================

STEP 2: ENABLE ABAC ON API SERVER
---------------------------------
Edit kube-apiserver configuration.

If using kubeadm:
------------------
Edit static pod manifest:

/etc/kubernetes/manifests/kube-apiserver.yaml

Add / update flags:

--authorization-mode=ABAC
--authorization-policy-file=/etc/kubernetes/abac-policy.json

Example snippet:
----------------
- --authorization-mode=ABAC
- --authorization-policy-file=/etc/kubernetes/abac-policy.json

IMPORTANT:
- kube-apiserver WILL restart automatically
- Any change to policy file later REQUIRES restart again

===============================================================================================

STEP 3: VERIFY API SERVER IS RUNNING
-----------------------------------
kubectl get pods -n kube-system | grep kube-apiserver

STATUS should be:
Running

===============================================================================================

STEP 4: CREATE A USER (seema)
-----------------------------
ABAC uses USERNAME from authentication.
We’ll simulate a user via certificate.

Create a client certificate with CN=seema.

Example (simplified):
---------------------
openssl genrsa -out seema.key 2048

openssl req -new -key seema.key \
  -subj "/CN=seema" \
  -out seema.csr

Sign with cluster CA (demo setup).

===============================================================================================

STEP 5: CREATE kubeconfig FOR seema
-----------------------------------
kubectl config set-credentials seema \
  --client-certificate=seema.crt \
  --client-key=seema.key

kubectl config set-context seema-context \
  --cluster=kubernetes \
  --user=seema \
  --namespace=default

kubectl config use-context seema-context

===============================================================================================

STEP 6: TEST ALLOWED ACTION (LIST PODS)
---------------------------------------
kubectl get pods

EXPECTED RESULT:
✔ Pods are listed

WHY?
- user = seema
- resource = pods
- verb = list
- namespace = default
→ Rule matches → ALLOWED

===============================================================================================

STEP 7: TEST ALLOWED ACTION (GET POD)
-------------------------------------
kubectl get pod <pod-name>

EXPECTED RESULT:
✔ Pod details shown

WHY?
- verb = get
- Explicitly allowed in ABAC policy

===============================================================================================

STEP 8: TEST DENIED ACTION (CREATE POD)
---------------------------------------
kubectl run test --image=nginx

EXPECTED RESULT:
❌ Forbidden

ERROR (example):
Error from server (Forbidden): pods is forbidden

WHY?
- verb = create
- NO rule allowing "create"
- ABAC rules are explicit
- No implicit permissions

===============================================================================================

STEP 9: TEST DENIED ACTION (OTHER RESOURCE)
-------------------------------------------
kubectl get services

EXPECTED RESULT:
❌ Forbidden

WHY?
- resource = services
- Policy only allows "pods"

===============================================================================================

STEP 10: MODIFY ABAC POLICY (ADD CREATE)
----------------------------------------
Edit /etc/kubernetes/abac-policy.json

Add:
{
  "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
  "kind": "Policy",
  "spec": {
    "user": "seema",
    "namespace": "default",
    "resource": "pods",
    "verb": "create"
  }
}

IMPORTANT:
🚨 THIS CHANGE DOES NOTHING YET 🚨

===============================================================================================

STEP 11: RESTART API SERVER (REQUIRED!)
---------------------------------------
Because ABAC policies are STATIC:

- Restart kube-apiserver
- (kubeadm users: file change triggers restart automatically)

Verify:
kubectl get pods -n kube-system

===============================================================================================

STEP 12: RETEST CREATE POD
-------------------------
kubectl run test --image=nginx

EXPECTED RESULT:
✔ Pod created

WHY?
- New rule loaded after restart

===============================================================================================

WHAT YOU JUST PROVED
--------------------
✔ ABAC evaluates rules sequentially
✔ No roles
✔ No bindings
✔ No grouping
✔ No dynamic updates
✔ Restart required on every change

===============================================================================================

WHY ABAC IS BAD (REAL-WORLD PROBLEMS)
-------------------------------------
❌ Policy file grows HUGE
❌ Hard to audit
❌ Hard to reason
❌ No reuse (copy-paste rules)
❌ API server restart required
❌ Error-prone
❌ Not scalable

===============================================================================================

ABAC vs RBAC (ONE-LINE COMPARISON)
----------------------------------
ABAC = Static firewall rules
RBAC = Structured access model

===============================================================================================

WHEN ABAC IS USED TODAY
-----------------------
✔ Historical clusters
✔ Academic learning
✔ Interview theory
❌ Production
❌ Modern Kubernetes

===============================================================================================

MENTAL MODEL
------------
ABAC:
IF user == X AND verb == Y AND resource == Z → ALLOW

RBAC:
User → Role → Permissions → Resources

===============================================================================================

FINAL TAKEAWAY
--------------
ABAC taught Kubernetes WHAT NOT TO DO.
RBAC is the answer.

===============================================================================================
END OF PRACTICAL
===============================================================================================

If you want next:
- ABAC → RBAC migration demo
- Webhook authorization demo
- RBAC vs ABAC attack scenarios
- CKA / CKS exam traps explained
```
