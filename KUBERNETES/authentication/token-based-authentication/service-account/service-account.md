### **Service Accounts in Kubernetes**  
While human users authenticate to a Kubernetes cluster using mechanisms such as **External Identity Providers & TLS certificates**, any **non-human interaction** with the cluster is typically done through **Service Accounts**.

![Alt text](/images/37c.png)

### **Why Are Service Accounts Necessary?**  
Service Accounts serve as identities for workloads and automation tools interacting with Kubernetes. Instead of using a normal user account, Service Accounts allow these systems to securely authenticate and perform operations within the cluster.

They are commonly used by:
- **CI/CD Pipelines** (e.g., Jenkins, GitLab CI/CD) to deploy applications.
- **Monitoring Agents** (e.g., Prometheus, Datadog, New Relic, Sysdig) to collect metrics.
- **Logging Solutions** (e.g., Fluentd, ELK Stack, Loki) to process and store logs.
- **Security Solutions** (e.g., Aqua Security, Falco, Sysdig Secure) to enforce security policies.
- **Policy Enforcers** (e.g., Open Policy Agent (OPA), Gatekeeper, Kyverno) to apply governance rules.
- **Backup and Disaster Recovery Tools** (e.g., Velero, Stash) to automate backup processes.
- **Secret Management Systems** (e.g., HashiCorp Vault, Sealed Secrets) to securely store and manage secrets.

Whenever an **external tool or service** interacts with a Kubernetes cluster, it usually does so using a **Service Account**, ensuring that operations are clearly distinguishable from human user actions.

---

### **Should You Use a Normal User Account for Automation?**  
Technically, **yes**, but **it is strongly discouraged**.  
Using a normal user account for automated tasks can lead to serious security and auditing issues:
- **Log Ambiguity**: When investigating logs, you won’t easily differentiate between human and automated actions.
- **Security Risks**: If the user account gets compromised, automation workflows may be affected, or vice versa.
- **Poor Access Management**: Service Accounts allow fine-grained control over permissions, whereas regular user accounts may have broader privileges.

Administrators often refer to **Service Accounts with specific names** such as:
- `automation-account`
- `cicd-account`
- `monitoring-agent`
- `policy-enforcer`

These naming conventions help distinguish **system-driven** actions from **human-driven** operations.

Imagine seeing this in your audit logs:
```
User 'admin' created a pod in prod
```
**vs**
```
ServiceAccount 'jenkins-deployer' created a pod in prod
```
Only one of those tells you **who or what** really performed the action.

---

### **Managing Service Account Permissions**
Like human users, **Service Accounts require proper access control**. You can assign:
- **Roles (`Role` and `ClusterRole`)** to define permissions.
- **RoleBindings (`RoleBinding` and `ClusterRoleBinding`)** to grant access.

---

```bash
# KUBERNETES SERVICEACCOUNT + RBAC + RAW API ACCESS (COMPLETE TUTORIAL BOX)

#CONCEPT (VERY IMPORTANT)
  #  - Authentication: Who are you?
  #    • Pod → ServiceAccount token (JWT)
  #  - Authorization: What can you do?
  #    • RBAC (Role / ClusterRole + Bindings)
  #  - Admission: Final validation

  #  Flow:
  #  Pod → ServiceAccount Token → API Server → RBAC → Response

#------------------------------------------------------------

# SERVICEACCOUNT BASICS
  #  - Default ServiceAccount exists in every namespace
  #  - Token auto-mounted inside pod at:
  #    /var/run/secrets/kubernetes.io/serviceaccount/

  #  Files:
  #  - token     → JWT used for auth
  #  - ca.crt    → API server CA
  #  - namespace → Pod namespace

#------------------------------------------------------------

# CREATE SERVICEACCOUNT
kubectl create serviceaccount mysa

#------------------------------------------------------------

# CREATE POD USING SERVICEACCOUNT
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: mysa
  containers:
  - name: app
    image: nginx
    command: ["sleep","3600"]
EOF

#------------------------------------------------------------

# EXEC INTO POD
kubectl exec -it my-app -- bash

#------------------------------------------------------------

# INSIDE POD – LOAD TOKEN
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

#------------------------------------------------------------

# CALL KUBERNETES API (NO RBAC → FAIL EXPECTED)
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api

#------------------------------------------------------------

# TRY LIST PODS (403 EXPECTED)
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/default/pods

#------------------------------------------------------------

# CREATE ROLE (NAMESPACE-SCOPED)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
 - apiGroups: [""]
   resources: ["pods"]
   verbs: ["get","list","watch"]
EOF

#------------------------------------------------------------

# BIND ROLE TO SERVICEACCOUNT
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: mysa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

#------------------------------------------------------------

# VERIFY PERMISSION (OUTSIDE POD)
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:mysa \
  --namespace=default

#------------------------------------------------------------

# RETRY POD LIST (NOW WORKS)
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/default/pods

#------------------------------------------------------------
# CREATE CLUSTERROLE
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-node-viewer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["all"]
- apiGroups: [""]
  resources: ["nodes","nodes/status"]
  verbs: ["get","list","watch"]
EOF

#------------------------------------------------------------

# BIND CLUSTERROLE TO SERVICEACCOUNT
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pod-node-viewer-rb
subjects:
- kind: ServiceAccount
  name: mysa
  namespace: default
roleRef:
  kind: ClusterRole
  name: pod-node-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

#------------------------------------------------------------

# VERIFY NODE ACCESS
kubectl auth can-i list nodes \
  --as=system:serviceaccount:default:mysa

#------------------------------------------------------------

# CALL NODES API FROM POD
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/nodes

#------------------------------------------------------------
```

---

### **Following the Principle of Least Privilege**
When configuring **Service Account permissions**, it’s critical to **only grant necessary privileges**.  
For example:
- A **monitoring agent** typically requires only `get`, `list`, and `watch` permissions—nothing more.
- A **CI/CD pipeline** may need `patch`, `apply`, and `create` permissions, but **should not** have unrestricted cluster-wide access.
- A **policy enforcer** like OPA or Kyverno should only have permissions to review policies and enforce governance rules.

Ensuring **minimal privileges** improves security and prevents potential misconfigurations.

---

### How Do ServiceAccounts Authenticate with the Cluster?

When you create a new **namespace**, Kubernetes automatically provisions a **default ServiceAccount (SA)** for it. Any **Pod** launched in that namespace will, by default, be associated with this SA unless explicitly overridden.

---

### Associating a ServiceAccount with a Pod
To use a custom ServiceAccount with a Pod or Deployment, specify the `serviceAccountName` field in the **Pod spec** — at the same level as `containers`. If you want to prevent Kubernetes from mounting any ServiceAccount token (including the default), you can disable it by setting `automountServiceAccountToken: false`.

By Default each namespace have the default service account:
```bash
controlplane:~$ kubectl get sa default
NAME      SECRETS   AGE
default   0         6d15h

controlplane:~$ kubectl get sa default -oyaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2025-11-17T19:09:40Z"
  name: default
  namespace: default
  resourceVersion: "456"
  uid: d262d02a-29a4-4e05-a3d7-6a1720d88b76

controlplane:~$ kubectl describe sa default   
Name:                default
Namespace:           default
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```

**Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      serviceAccountName: jenkins-sa
      automountServiceAccountToken: false  # Set to false to disable automatic token mounting
      containers:
        - name: my-app-container
          image: nginx:1.27
```
```bash
kubectl create sa mysa

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: mysa
  automountServiceAccountToken: true  # Set to false to disable automatic token mounting
  containers:
  - name: my-app-container
    image: nginx:1.27
EOF

kubectl exec -it my-app -- ls /var/run/secrets/kubernetes.io/serviceaccount/


```

---

### Why Does This Matter?
Pods often need to **communicate with the Kubernetes API server** — for example, to read ConfigMaps, fetch Secrets, or list Services.
This interaction must be **authenticated**, and the **ServiceAccount token** provides that identity.

---

### Evolution of ServiceAccount Tokens

| Feature               | Before Kubernetes v1.24                   | Kubernetes v1.24 and Later              |
| --------------------- | ----------------------------------------- | --------------------------------------- |
| Token creation        | Auto-generated and stored in a **Secret** | Not created by default                  |
| Token type            | Long-lived, **no expiration**             | Short-lived, **projected tokens**       |
| Storage               | Stored in etcd as **Secrets**             | Dynamically projected, **not stored**   |
| Token mounting        | Yes, via volume                           | Yes, but with **short-lived tokens**    |
| Security implications | Risk of indefinite reuse if leaked        | Safer; time-bound and optionally scoped |

---

#### Why the Change?
Older tokens had no expiration and were stored as Secrets — if compromised, they could be used forever.
**Projected tokens** introduced in v1.24 address this:

* **Time-bound**: Expire automatically (default is 1 hour)
* **Signed and scoped**: Tied to specific audiences and permissions
* **Refreshable**: Through the **TokenRequest API**

---

### Where Is the ServiceAccount Token Mounted?

Kubernetes automatically mounts the token and related metadata inside the Pod as a volume.

#### You can inspect the mount using:

```bash
kubectl describe pod <pod-name>
```

Look for:

```
Mounts:
/var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-xxxxx (ro)
```

#### Or view the contents:

```bash
kubectl exec -it <pod-name> -- bash
cd /var/run/secrets/kubernetes.io/serviceaccount
ls
cat token #JWT  Token
```

This will show:

* `ca.crt`: The CA cert used to verify the API server’s TLS certificate
* `namespace`: The namespace the Pod is running in
* `token`: A **JWT token** used for authenticating with the API server

You can decode the token on [jwt.io](https://jwt.io) to inspect its claims (like `iss`, `sub`, `aud`, etc.).

---

### How a Pod Authenticates with the API Server Using a ServiceAccount

> ⚠️ **Note:**
> This section primarily describes the behavior of the **default ServiceAccount** that is automatically associated with every pod. This default SA allows basic access (like reading ConfigMaps and Secrets) within the namespace.
> However, for specialized workloads — such as monitoring, logging, or security tools that run as **DaemonSets** — custom **ServiceAccounts** with tailored permissions are typically used. These pods follow the same authentication mechanism, but their authorization (via RBAC) is scoped to the needs of the tool.
>These tools are typically deployed using **Helm**, which simplifies the setup by provisioning all necessary Kubernetes resources — such as DaemonSets, ServiceAccounts, Services, and even Custom Resource Definitions (CRDs). We’ll explore CRDs later in this course.

![Alt text](/images/37d.png)

1. **ServiceAccount Automatically Mounted**
   Whenever a Pod is created — whether by a Deployment, StatefulSet, ReplicaSet, Job, cronjob, DaemonSet, or directly — a ServiceAccount (SA) is automatically associated with it.
   By default, Kubernetes mounts this SA’s token and certificate into the Pod. The Pod then uses this token to authenticate with the API server when performing operations like fetching ConfigMaps, Secrets, or talking to the Kubernetes API.

2. **What Gets Mounted**
   The SA credentials are mounted under:
   ```
   /var/run/secrets/kubernetes.io/serviceaccount
   ```

   Inside this path, you will typically find:
   * `ca.crt` – The public certificate of the Kubernetes cluster’s certificate authority (CA)
   * `namespace` – The namespace in which the Pod is running
   * `token` – A signed JWT used to authenticate as the Pod’s SA

3. **Authentication via mTLS-Like Flow**
   This communication works on a principle similar to mutual TLS (mTLS), though technically only the server (API server) presents a certificate:
   * The **Pod is the client** — it initiates the request to the API server.
   * The **API server is the server** — it presents its certificate.
   * The Pod verifies the API server’s certificate using the `ca.crt` file (the CA that signed the API server’s certificate).
   * The Pod then presents its **JWT token** (from the `token` file) in the `Authorization` header.
     > The token mounted into the Pod is a **projected ServiceAccount token**, which is **scoped, time-bound, and cryptographically signed** by the API server, ensuring secure and limited access.

     > These are called projected tokens because they are "projected" into the Pod’s filesystem by Kubernetes when a Service Account is assigned to it.

     >You can paste this token into [jwt.io](https://jwt.io/) to decode and inspect its claims.
   * Since the token was **signed by the API server’s private key**, the API server can verify its authenticity using its public key.
      > The `kid` value, that you see while you decode the token, identifies the public key that corresponds to the private key used to sign the token.



4. **Authentication Succeeds**
   Once the token is validated, the API server identifies the request as coming from the associated ServiceAccount (and any groups linked to it, such as `system:serviceaccounts`, `system:serviceaccounts:<namespace>`).

5. **Then Comes Authorization**
   After successful authentication, the request flows through the **authorization phase** (typically RBAC), where the API server checks whether this ServiceAccount is allowed to perform the requested action on the specified resource.

```bash
==================== KUBERNETES SERVICEACCOUNT TOKEN – COMPLETE HANDS-ON DEMO ====================

GOAL
- See how a ServiceAccount (SA) token is auto-mounted
- Use that token from inside a Pod
- Call the Kubernetes API
- Observe Authentication vs Authorization (RBAC)

===============================================================================================

STEP 1: Create a namespace
--------------------------
kubectl create ns sa-demo

===============================================================================================

STEP 2: Create a ServiceAccount
-------------------------------
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-sa
  namespace: sa-demo
EOF

===============================================================================================

STEP 3: Create a Pod using this ServiceAccount
----------------------------------------------
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sa-test-pod
  namespace: sa-demo
spec:
  serviceAccountName: demo-sa
  containers:
  - name: curl
    image: curlimages/curl
    command: ["sleep", "3600"]
EOF

===============================================================================================

STEP 4: Exec into the Pod
------------------------
kubectl exec -it sa-test-pod -n sa-demo -- sh

===============================================================================================

STEP 5: Inspect auto-mounted ServiceAccount files
-------------------------------------------------
ls /var/run/secrets/kubernetes.io/serviceaccount

You will see:
- token       → JWT used for authentication
- ca.crt      → Cluster CA certificate
- namespace   → Namespace of the Pod

===============================================================================================

STEP 6: Confirm namespace from inside Pod
------------------------------------------
cat /var/run/secrets/kubernetes.io/serviceaccount/namespace

Output:
sa-demo

===============================================================================================

STEP 7: Read and decode the ServiceAccount token
------------------------------------------------
cat /var/run/secrets/kubernetes.io/serviceaccount/token

- Copy the token
- Paste into https://jwt.io
- Observe:
  - iss  → Kubernetes API server
  - sub  → system:serviceaccount:sa-demo:demo-sa
  - aud  → https://kubernetes.default.svc.cluster.local
  - exp  → token expiry
  - kid  → key-id used to verify signature

===============================================================================================

STEP 8: Call Kubernetes API WITHOUT token (FAIL)
------------------------------------------------
curl https://kubernetes.default.svc/api

Result:
401 Unauthorized

Reason:
- No authentication credentials provided

===============================================================================================

STEP 9: Call Kubernetes API WITH token and CA
---------------------------------------------
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

curl --cacert $CACERT \
     -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api

Result:
- API versions returned

Meaning:
- Authentication SUCCESSFUL

===============================================================================================

STEP 10: Try listing Pods (Authorization FAIL)
----------------------------------------------
curl --cacert $CACERT \
     -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api/v1/namespaces/sa-demo/pods

Result:
403 Forbidden

Meaning:
- Authenticated ✔
- Not Authorized ❌ (RBAC denied)

===============================================================================================

STEP 11: Grant RBAC permissions
-------------------------------
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: sa-demo
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: sa-demo
subjects:
- kind: ServiceAccount
  name: demo-sa
  namespace: sa-demo
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

===============================================================================================

STEP 12: Retry API call (Authorization SUCCESS)
-----------------------------------------------
curl --cacert $CACERT \
     -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api/v1/namespaces/sa-demo/pods

Result:
- Pod list returned

Meaning:
- Authentication ✔
- Authorization ✔

===============================================================================================

STEP 13: Disable token auto-mount (Security demo)
-------------------------------------------------
apiVersion: v1
kind: Pod
spec:
  automountServiceAccountToken: false

Result:
- /var/run/secrets/kubernetes.io/serviceaccount does NOT exist
- Any Kubernetes API call FAILS

===============================================================================================

END-TO-END FLOW SUMMARY
-----------------------
Pod created
→ ServiceAccount auto-attached
→ Token + CA projected into filesystem
→ Pod verifies API server using ca.crt
→ Pod sends JWT token
→ API server authenticates (signature + kid)
→ RBAC authorizes request

===============================================================================================

REAL-WORLD ANALOGY
------------------
ServiceAccount  = IAM Role
JWT Token       = Temporary credentials
RBAC            = IAM Policy
API Server      = AWS STS + AWS Service API

===============================================================================================
```

---

#### Why This Matters

* This is how Kubernetes **authenticates workloads**, not just human users.
* Without this token, in-cluster apps cannot securely talk to the API server.
* It also highlights why the **principle of least privilege** is essential — every ServiceAccount (default or custom) should have only the permissions it needs.

---

## Types of ServiceAccount Tokens in Kubernetes

We can categorize ServiceAccount tokens into **three types based on usage and lifecycle** — but it’s important to know that **projected tokens are actually obtained via the TokenRequest API**, so they’re not separate in terms of mechanism.
They required a service account which need to be created first.

![Alt text](/images/37e.png)
---

### 1. **Bound ServiceAccount Tokens (aka Projected Tokens via TokenRequest API)**

**Use case**: Internal systems (pods)

* These tokens are **automatically issued using the TokenRequest API** when a pod is created and uses a ServiceAccount.
* They are **short-lived (\~1 hour)**, **signed**(api-server private key), **scoped** (via RBAC), and **auto-rotated** by the kubelet.
* Mounted at: `/var/run/secrets/kubernetes.io/serviceaccount/token`
* This is the **recommended default for pods** accessing the API server.
* How short-lived tokens are delivered to Pods (Mounting)
* Pods receive tokens through a projected service account token volume
* Mounted automatically at: `/var/run/secrets/kubernetes.io/serviceaccount/token`
* But this token is:
  * NOT read from a Secret
  * Generated dynamically by the TokenRequest API
  * Automatically refreshed by the kubelet
  * Short-lived (default 10 minutes)
  * Updated automatically without pod restart

```yaml
  volumes:
  - name: kube-api-access-zlc7p
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          items:
          - key: ca.crt
            path: ca.crt
          name: kube-root-ca.crt
      - downwardAPI:
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
            path: namespace
```
```text
==================== BOUND SERVICEACCOUNT (PROJECTED) TOKEN – FULL PRACTICAL DEMO ====================

This demo shows:
- How Bound (Projected) ServiceAccount tokens work
- How Kubernetes auto-mounts them
- How YOU can manually define the projected volume
- How rotation + short-lived tokens behave

===============================================================================================

BACKGROUND (WHAT YOU ARE DEMOING)
---------------------------------
- Token type        : Bound ServiceAccount Token(projected token)
- Issued by         : TokenRequest API
- Signed by         : kube-apiserver private key
- Lifetime          : Short-lived (default ~10–60 minutes)
- Rotation          : Automatic (by kubelet)
- Storage           : NOT stored in Secrets
- Delivery method  : Projected volume
- Recommended use  : Pods accessing Kubernetes API

===============================================================================================

STEP 1: Create Namespace
------------------------
kubectl create namespace sa-demo

===============================================================================================

STEP 2: Create a ServiceAccount
-------------------------------
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-sa
  namespace: sa-demo
EOF

NOTE:
- No Secret is created
- Token will be issued dynamically per Pod

===============================================================================================

STEP 3: MANUALLY CREATE POD WITH PROJECTED TOKEN VOLUME
-------------------------------------------------------
This explicitly shows what Kubernetes normally does automatically.

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: projected-token-pod
  namespace: sa-demo
spec:
  serviceAccountName: demo-sa
  containers:
  - name: app
    image: curlimages/curl
    command: ["sleep", "3600"]
    volumeMounts:
    - name: kube-api-access
      mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      readOnly: true
  volumes:
  - name: kube-api-access
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 600
          audience: https://kubernetes.default.svc.cluster.local
      - configMap:
          name: kube-root-ca.crt
          items:
          - key: ca.crt
            path: ca.crt
      - downwardAPI:
          items:
          - path: namespace
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
EOF

KEY POINTS:
- Token comes from TokenRequest API
- expirationSeconds controls token TTL
- audience restricts token usage
- Token auto-rotates
- No Secret involved

===============================================================================================

STEP 4: Exec Into Pod
---------------------
kubectl exec -it projected-token-pod -n sa-demo -- sh

===============================================================================================

STEP 5: Inspect Mounted Files
-----------------------------
ls /var/run/secrets/kubernetes.io/serviceaccount

You will see:
- token
- ca.crt
- namespace

===============================================================================================

STEP 6: Confirm Token Is SHORT-LIVED
------------------------------------
cat /var/run/secrets/kubernetes.io/serviceaccount/token

- Paste into https://jwt.io
- Observe:
  - exp → expires in ~10 minutes
  - iat → issued time
  - aud → kubernetes API
  - sub → system:serviceaccount:sa-demo:demo-sa
  - kubernetes.io → pod + node + SA binding

This confirms:
✔ Pod-bound
✔ Namespace-bound
✔ Time-bound

===============================================================================================

STEP 7: Watch TOKEN ROTATION LIVE
--------------------------------
Inside the Pod:

watch -n 5 cat /var/run/secrets/kubernetes.io/serviceaccount/token

- You will see token VALUE change before expiry
- No Pod restart
- Kubelet refreshes token automatically

THIS IS THE CORE FEATURE OF PROJECTED TOKENS

===============================================================================================

STEP 8: Call Kubernetes API USING TOKEN
---------------------------------------
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

curl --cacert $CACERT \
     -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api

Result:
- API versions returned

Meaning:
✔ Authentication succeeded

===============================================================================================

STEP 9: Try Unauthorized Request (RBAC FAIL)
---------------------------------------------
curl --cacert $CACERT \
     -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api/v1/namespaces/sa-demo/pods

Result:
403 Forbidden

Reason:
- Authenticated
- Not authorized by RBAC

===============================================================================================

STEP 10: Grant RBAC Permission
------------------------------
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: sa-demo
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: sa-demo
subjects:
- kind: ServiceAccount
  name: demo-sa
  namespace: sa-demo
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

===============================================================================================

STEP 11: Retry API Call (RBAC SUCCESS)
--------------------------------------
curl --cacert $CACERT \
     -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api/v1/namespaces/sa-demo/pods

Result:
- Pod list returned

===============================================================================================

IMPORTANT COMPARISON (WHY THIS MATTERS)
---------------------------------------
OLD MODEL (Secrets):
- Long-lived tokens
- Stored in Secrets
- No rotation
- Security risk

NEW MODEL (Projected Tokens):
- Short-lived
- Auto-rotated
- Pod-bound
- Audience-scoped
- No Secrets
- DEFAULT since K8s 1.21+

===============================================================================================

MENTAL MODEL
------------
Pod
 → TokenRequest API
 → Short-lived JWT
 → Mounted via projected volume
 → Verified by API server
 → Authorized by RBAC

===============================================================================================

WHEN TO USE THIS
----------------
✔ Internal Pods accessing Kubernetes API
✔ Controllers / Operators
✔ CI jobs inside cluster

```


---

### 2. **Manually Requested Tokens (TokenRequest API for external tools)**

**Use case**: External systems (like Jenkins, GitHub Actions, CI/CD tools)

* You (or the tool) call the TokenRequest API manually to obtain a **short-lived, signed, scoped JWT** for a ServiceAccount.
* This token can then be passed in API calls to authenticate.
* **Rotation must be handled manually** or by the external tool itself.
* Also recommended over static secrets.
* When an external system (not running inside Kubernetes) needs to authenticate to the Kubernetes API using a ServiceAccount, the recommended method is to use the TokenRequest API.
* Tokens are never stored in Secrets
* This is far more secure than:
  * old long-lived ServiceAccount tokens stored in Secrets
  * static tokens
  * manually created Secrets
  * embedding tokens in files
* Short-lived tokens are:
  * NOT stored in Secrets
  * NOT written to disk by the API server
  * Generated dynamically using the TokenRequest API
  * Issued on-demand and expire automatically
  * Signed immediately
  * Returned to the caller
  * Held only by:
    * the external application requesting it
    * or the kubelet (if projected into a Pod)

➡️ They exist only in memory and in the JWT returned to the caller.


* How to Request a Token Manually
```bash
kubectl create namespace devops-tools

kubectl create sa -n devops-tools api-service-account

kubectl create token <service-account> -n <namespace> #This returns a fresh short-lived JWT.(10min life)

export TOKEN=$(kubectl create token api-service-account -n devops-tools --duration=10m --audience=https://kubernetes.default.svc.cluster.local)

curl -k \
     -H "Authorization: Bearer $TOKEN" \
     $(kubectl config view -ojsonpath='{.clusters[0].cluster.server}')/api

curl -k \
     -H "Authorization: Bearer $TOKEN" \
     https:///version

curl --cacert /etc/kubernetes/pki/ca.crt \
     -H "Authorization: Bearer $TOKEN" \
      https://172.30.1.2:6443/api

kubectl create role pod-viewer \
  --verb=get,list,watch \
  --resource=pods \
  -n devops-tools

kubectl create rolebinding api-viewer-binding \
  --role=pod-viewer \
  --serviceaccount=devops-tools:api-service-account \
  -n devops-tools

curl --cacert /etc/kubernetes/pki/ca.crt \
     -H "Authorization: Bearer $TOKEN" \
      https://172.30.1.2:6443/api/v1/namespaces/devops-tools/pods

curl --cacert /etc/kubernetes/pki/ca.crt -H "Authorization: Bearer $TOKEN" https://172.30.1.2:6443/api/v1 | grep -i -A9 -B1 serviceaccounts/token
    {
      "name": "serviceaccounts/token",
      "singularName": "",
      "namespaced": true,
      "group": "authentication.k8s.io",
      "version": "v1",
      "kind": "TokenRequest",
      "verbs": [
        "create"
      ]
    }

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: token-creator
  namespace: devops-tools
rules:
- apiGroups: [""]
  resources: ["serviceaccounts/token"]
  verbs: ["create"]
EOF


kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: token-creator-binding
  namespace: devops-tools
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: token-creator
subjects:
- kind: ServiceAccount
  name: api-service-account
  namespace: devops-tools
EOF



#In automation tools
curl -k \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{
    "apiVersion": "authentication.k8s.io/v1",
    "kind": "TokenRequest",
    "spec": {
      "audiences": ["https://kubernetes.default.svc.cluster.local"],
      "expirationSeconds": 600
    }
  }' \
  https://<API-SERVER>/api/v1/namespaces/devops-tools/serviceaccounts/api-service-account/token \
  -H "Authorization: Bearer <admin-or-ci-token>"

curl -k \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{
    "apiVersion": "authentication.k8s.io/v1",
    "kind": "TokenRequest",
    "spec": {
      "audiences": ["https://kubernetes.default.svc.cluster.local"],
      "expirationSeconds": 600
    }
  }' \
  $(kubectl config view -ojsonpath='{.clusters[0].cluster.server}')/api/v1/namespaces/devops-tools/serviceaccounts/api-service-account/token \
  -H "Authorization: Bearer ${TOKEN}"

TOKEN_REQ=$(curl -sk \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  --data '{"apiVersion":"authentication.k8s.io/v1","kind":"TokenRequest","spec":{"expirationSeconds":600}}' \
  $(kubectl config view -ojsonpath='{.clusters[0].cluster.server}')/api/v1/namespaces/devops-tools/serviceaccounts/api-service-account/token)

echo "$TOKEN_REQ"


```
* Token Rotation
  * Short-lived tokens expire automatically.
  * External tools must handle rotation by:
  * Requesting a new token periodically
  * Before expiry (e.g., every 5–10 minutes)
  * Using the TokenRequest API again
```bash
while true; do
  TOKEN=$(kubectl create token api-service-account -n devops-tools)
  echo "$TOKEN" > /opt/app/k8s-token.txt
  sleep 300
done
```
* External app stores token somewhere
  ```bash
  TOKEN=$(kubectl create token api-service-account -n devops-tools)
  #Store it in:
  #File
  #Environment variable
  #Secret manager
  #Redis
  #Vault
  echo $TOKEN > /opt/app/k8s-token.txt
  ```
* App uses token in all API calls
```bash
curl -k https://<api-server>/api/v1/pods \
     -H "Authorization: Bearer $(cat /opt/app/k8s-token.txt)"
```
* Periodically rotate token (auto-refresh loop)
  * Short-lived tokens usually last 10 minutes.
  * External apps should refresh before expiry, e.g., every 5 minutes:
```bash
#!/bin/bash

NAMESPACE="devops-tools"
SERVICE_ACCOUNT="api-service-account"
TOKEN_FILE="/opt/app/k8s-token.txt"

while true; do
    NEW_TOKEN=$(kubectl create token $SERVICE_ACCOUNT -n $NAMESPACE)

    if [ -n "$NEW_TOKEN" ]; then
        echo "$NEW_TOKEN" > $TOKEN_FILE
        echo "[INFO] Token rotated at $(date)"
    else
        echo "[ERROR] Failed to rotate token at $(date)"
    fi

    sleep 300   # refresh every 5 minutes
done
```
* Using API request instead of kubectl (Advanced)
```bash
POST https://<api-server>/api/v1/namespaces/devops-tools/serviceaccounts/api-service-account/token

#Request body:
{
  "apiVersion": "authentication.k8s.io/v1",
  "kind": "TokenRequest",
  "spec": {
    "audiences": ["api"],
    "expirationSeconds": 600
  }
}

#100% API-driven
#Does not require kubectl
#Useful for apps written in Go/Python/Java/Node.js
```
* Store token in Vault and rotate using Vault Agent (Production-grade)
  * HashiCorp Vault can:
  * fetch short-lived tokens
  * rotate them automatically
  * inject them into your app
  * This is best for enterprise systems.

```bash
==================== MANUALLY REQUESTED SERVICEACCOUNT TOKENS (TokenRequest API) ====================

- How external systems authenticate to Kubernetes
- How to request short-lived tokens manually
- How rotation works
- Why this is the RECOMMENDED approach for CI/CD & tools

Token type        : Manually requested ServiceAccount token
API used          : TokenRequest API
Lifetime          : Short-lived (default 10m)
Rotation          : Manual / tool-managed
Storage           : NOT stored in Secrets
Security level    : ✅ Recommended for external systems

Used by:
- Jenkins
- GitHub Actions
- GitLab CI
- External scripts
- Monitoring systems outside the cluster

===============================================================================================

PREREQUISITES
-------------
- kubectl access to cluster
- Permission to request tokens
- Kubernetes v1.21+

===============================================================================================

STEP 1: Create Namespace for External Tools
-------------------------------------------
kubectl create namespace devops-tools

===============================================================================================

STEP 2: Create a ServiceAccount
-------------------------------
kubectl create serviceaccount api-service-account -n devops-tools

Verify:
kubectl describe sa api-service-account -n devops-tools

Observation:
- Tokens: <none>
- No Secret created (correct behavior)

===============================================================================================

STEP 3: Grant RBAC Permissions
------------------------------
This SA must be allowed to do something.

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: devops-tools
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: devops-tools
subjects:
- kind: ServiceAccount
  name: api-service-account
  namespace: devops-tools
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

===============================================================================================

STEP 4: REQUEST A TOKEN USING kubectl (SIMPLE WAY)
--------------------------------------------------
kubectl create token api-service-account \
  -n devops-tools \
  --duration=10m \
  --audience=api

Output:
- A JWT token is printed to stdout
- This token exists ONLY in your terminal memory

IMPORTANT:
✔ No Secret created
✔ No etcd storage
✔ Auto-expires

===============================================================================================

STEP 5: Decode the Token (jwt.io)
--------------------------------
Paste token into https://jwt.io

Observe:
- exp → expires in ~10 minutes
- aud → "api"
- sub → system:serviceaccount:devops-tools:api-service-account
- iss → kubernetes API server

CONFIRMATION:
✔ Short-lived
✔ Audience-scoped
✔ ServiceAccount-bound

===============================================================================================

STEP 6: Use Token to Call Kubernetes API
----------------------------------------
API_SERVER="https://<API-SERVER>:6443"

curl -k \
  -H "Authorization: Bearer <TOKEN>" \
  $API_SERVER/api/v1/namespaces/devops-tools/pods

Result:
✔ Authentication successful
✔ Authorization allowed (RBAC)

===============================================================================================

STEP 7: WHAT HAPPENS AFTER EXPIRY
--------------------------------
Wait ~10 minutes, then retry API call.

Result:
401 Unauthorized

Meaning:
- Token EXPIRED
- Must request a new one

THIS IS INTENTIONAL SECURITY DESIGN

===============================================================================================

STEP 8: AUTOMATED TOKEN ROTATION (SHELL LOOP)
---------------------------------------------
External systems must refresh tokens BEFORE expiry.

Example script:

#!/bin/bash

NAMESPACE="devops-tools"
SERVICE_ACCOUNT="api-service-account"
TOKEN_FILE="/opt/app/k8s-token.txt"

while true; do
  TOKEN=$(kubectl create token $SERVICE_ACCOUNT -n $NAMESPACE --duration=10m)

  if [ -n "$TOKEN" ]; then
    echo "$TOKEN" > $TOKEN_FILE
    echo "[INFO] Token rotated at $(date)"
  else
    echo "[ERROR] Token rotation failed"
  fi

  sleep 300   # refresh every 5 minutes
done

===============================================================================================

STEP 9: APP USING THE TOKEN
---------------------------
External app reads token and calls API:

curl -k \
  -H "Authorization: Bearer $(cat /opt/app/k8s-token.txt)" \
  https://<API-SERVER>:6443/api

===============================================================================================

STEP 10: PURE API REQUEST (NO kubectl – ADVANCED)
-------------------------------------------------
This is how real CI tools work.

POST https://<API-SERVER>:6443/api/v1/namespaces/devops-tools/serviceaccounts/api-service-account/token

Headers:
Authorization: Bearer <admin-or-bootstrap-token>
Content-Type: application/json

Body:
{
  "apiVersion": "authentication.k8s.io/v1",
  "kind": "TokenRequest",
  "spec": {
    "audiences": ["api"],
    "expirationSeconds": 600
  }
}

Response:
{
  "status": {
    "token": "<JWT>",
    "expirationTimestamp": "..."
  }
}

✔ Token exists ONLY in response
✔ Caller stores it in memory / Vault / file

===============================================================================================

STEP 11: WHY THIS IS MORE SECURE THAN LEGACY TOKENS
---------------------------------------------------
LEGACY TOKEN (Secret-based):
- Stored in etcd
- Never expires
- Manual rotation
- Easy to leak ❌

TOKENREQUEST TOKEN:
- Generated on demand
- Short-lived
- Auto-expires
- Not stored
- Rotation friendly ✔

===============================================================================================

PRODUCTION-GRADE SETUP
----------------------
Best practices:
- Request token via API
- Store token in Vault / Secret Manager
- Auto-rotate before expiry
- Never commit token to git
- Never store long-lived tokens

===============================================================================================

MENTAL MODEL
------------
External tool
 → TokenRequest API
 → Short-lived JWT
 → API Server authentication
 → RBAC authorization
 → Token expires
 → Refresh

===============================================================================================

WHEN TO USE THIS METHOD
----------------------
✔ Jenkins / GitHub Actions
✔ External CI/CD
✔ Monitoring tools outside cluster
✔ Automation scripts

WHEN NOT TO USE
---------------
✖ Pods inside cluster (use projected tokens)
✖ Long-term credentials
✖ Static secrets

===============================================================================================

FINAL TAKEAWAY
--------------
TokenRequest API = Kubernetes equivalent of:
- AWS STS
- OAuth2 access tokens
- Temporary credentials

This is the MODERN, SECURE, RECOMMENDED way.

===============================================================================================
```

---

### 3. **Legacy (Perpetual) Tokens via Secrets**

**Use case**: Legacy internal or external use

* You create a SA → Then associate a Secret with the SA → You extract the token.
* This token is **long-lived**, **doesn’t expire by default**(manually rotation), and **not rotated**.
* **Not recommended** due to static nature and security risk.



```bash
kubectl create serviceaccount my-sa

cat <<EOF > my-sa-token.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-sa
type: kubernetes.io/service-account-token
EOF

kubectl apply -f my-sa-token.yaml

kubectl get secret my-sa-token -oyaml 

kubectl get secret my-sa-token -o jsonpath='{.data.token}' | base64 --decode
kubectl get secret my-sa-token -o jsonpath='{.data.namespace}' | base64 --decode
kubectl get secret my-sa-token -o jsonpath='{.data.ca\.crt}' | base64 --decode

#Authentication
Authorization: Bearer <token>

#Update all external systems
#Manually update:
#apps
#Jenkins
#GitHub Actions
#monitoring tools
#dashboards
#This is why rotation is painful and error-prone.


controlplane:~$ kubectl describe sa my-sa
Name:                my-sa
Namespace:           default
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              my-sa-token
Events:              <none>

controlplane:~$ kubectl create sa demo
serviceaccount/demo created

controlplane:~$ kubectl describe sa demo
Name:                demo
Namespace:           default
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none> #Default no token attach(after K8S 1.24+)
Events:              <none>
```

```json
eyJhbGciOiJSUzI1NiIsImtpZCI6IlU5cXBiY243UGUxNzNPMUZGRUVwZHlicHY5VHZqUEtaZUZQakdVSlFjbTgifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im15LXNhLXRva2VuIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6Im15LXNhIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYTBhMzkwMTQtZTgyNS00MGYwLTgzNjgtYTBjZDUxZDRhNjRjIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6bXktc2EifQ.wYABcAjf0zptle5_nsQyLbGuQ0Wr9oYawQi4CapWmrfunWXdlTiTiYXh4MyyKhoaAKsvEkzsUPt_P82WeKOmxnCxwdc-AoqTp_t3zmGPnfRZnGmIIjlmIADqmsJ0KRsKzkYMVWxn9PvcqC0zp9cKkOismpNhlL59n7lwpMb7Ix3hixd--xgFvrotr64FLT-kjX5PYsXXLIZQzjmzUNrUTI8qh6XH8WnhqEDlvGncw3YCMgSj6iO4l-p5kjEnepTiKB-GtSm3u5kYrmM1TDcCBT_4FiVdWTTQq2KQQZ1nD54y0YGjAu4SwYEPQSNOKRHTpmfKBfOr49uY91mxQjY1rw

#Decoded Header
{
  "alg": "RS256",
  "kid": "U9qpbcn7Pe173O1FFEEpdybpv9TvjPKZeFPjGUJQcm8"
}

#Decoded Payload
{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "default",
  "kubernetes.io/serviceaccount/secret.name": "my-sa-token",
  "kubernetes.io/serviceaccount/service-account.name": "my-sa",
  "kubernetes.io/serviceaccount/service-account.uid": "a0a39014-e825-40f0-8368-a0cd51d4a64c",
  "sub": "system:serviceaccount:default:my-sa"
}
```
```bash
==================== LEGACY (PERPETUAL) SERVICEACCOUNT TOKEN ====================

- How legacy ServiceAccount tokens via Secrets work
- Why they are called *perpetual*
- How they differ from projected (bound) tokens
- Why Kubernetes deprecated them (K8s ≥ 1.24)

Creation method  : Manually via Secret
Storage          : Stored in etcd as a Secret
Lifetime         : Long-lived (NO expiry)
Rotation         : Manual (painful)
Binding          : ServiceAccount only (NOT Pod-bound)
Security status  : ❌ NOT recommended

Used historically by:
- Jenkins
- Monitoring systems
- Dashboards
- External scripts

===============================================================================================

STEP 1: Create a ServiceAccount
-------------------------------
kubectl create serviceaccount my-sa

Verify:
kubectl describe sa my-sa

Observation:
- No token yet
- Kubernetes will NOT auto-create a token (K8s 1.24+)

===============================================================================================

STEP 2: Manually create a legacy token Secret
---------------------------------------------
cat <<EOF > my-sa-token.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-sa
type: kubernetes.io/service-account-token
EOF

Apply it:
kubectl apply -f my-sa-token.yaml

===============================================================================================

STEP 3: Kubernetes auto-populates the Secret
---------------------------------------------
kubectl get secret my-sa-token -o yaml

What Kubernetes injects:
- token     → JWT (LONG-LIVED)
- ca.crt    → Cluster CA
- namespace → Namespace (base64)

IMPORTANT:
- You never generate the token yourself
- API server signs it using its private key

===============================================================================================

STEP 4: Extract the token
-------------------------
kubectl get secret my-sa-token \
  -o jsonpath='{.data.token}' | base64 --decode

This token:
✔ Has NO exp
✔ Does NOT rotate
✔ Works forever unless revoked

===============================================================================================

STEP 5: Decode the token (jwt.io)
---------------------------------
Paste token into https://jwt.io

Observe PAYLOAD:
- iss: kubernetes/serviceaccount
- sub: system:serviceaccount:default:my-sa
- kubernetes.io/serviceaccount.secret.name
- kubernetes.io/serviceaccount.uid

CRITICAL DIFFERENCE:
❌ No exp
❌ No aud
❌ No pod binding
❌ No node binding

===============================================================================================

STEP 6: Authenticate using this token (External system)
--------------------------------------------------------
curl --cacert /path/to/ca.crt \
     -H "Authorization: Bearer <TOKEN>" \
     https://<API-SERVER-IP>:6443/api

curl --cacert /etc/kubernetes/pki/ca.crt \
     -H "Authorization: Bearer $TOKEN" \
     $(kubectl config view -ojsonpath='{.clusters[0].cluster.server}')/api

Result:
✔ Authentication SUCCESS

This is why external tools loved this token.

===============================================================================================

STEP 7: Authorization via RBAC
-------------------------------
Token identity:
system:serviceaccount:default:my-sa

RBAC decides:
- What APIs
- What namespaces
- What verbs

Authentication ≠ Authorization

===============================================================================================

STEP 8: Why rotation is painful (REAL PROBLEM)
-----------------------------------------------
Token leaks → you must:
1. Create new Secret
2. Update all systems manually:
   - Jenkins
   - GitHub Actions
   - Monitoring
   - Dashboards
3. Restart services
4. Hope no one missed updating

This is why breaches were catastrophic.

===============================================================================================

STEP 9: Observe difference in Kubernetes ≥ 1.24
------------------------------------------------
kubectl create sa demo
kubectl describe sa demo

Output:
Tokens: <none>

Meaning:
✔ Kubernetes stopped auto-creating legacy tokens
✔ Forces safer projected tokens

===============================================================================================

STEP 10: Why this token is DANGEROUS
-----------------------------------
Attack scenario:
- Token leaked from Jenkins log
- Attacker gains cluster access
- Token never expires
- Works from ANY machine
- No pod binding
- No audience restriction

This violated:
- Zero Trust
- Least privilege
- Short-lived credentials

===============================================================================================

COMPARISON SUMMARY
------------------
LEGACY TOKEN:
- Stored in Secret
- Long-lived
- No rotation
- External-friendly
- High risk ❌

PROJECTED TOKEN:
- Issued via TokenRequest API
- Short-lived
- Auto-rotated
- Pod-bound
- Secure ✔
```

---

### Summary Table:

| Type                      | Who Uses It    | Issued How                | Lifespan     | Rotation | Recommended |
| ------------------------- | -------------- | ------------------------- | ------------ | -------- | ----------- |
| Projected Token (Bound)   | Pods           | Auto via TokenRequest API | \~1 hour     | Yes      | ✅ Yes       |
| Manual TokenRequest API   | External tools | Manually call API         | Customizable | Manual   | ✅ Yes       |
| Legacy Secret-based Token | Legacy systems | Auto-created Secret       | Infinite     | No       | ❌ No        |

---


## **Non-Human Access to Kubernetes: A Detailed Breakdown**

In Kubernetes, many systems interact with the API server in automated ways — without human users. These **non-human access patterns** fall into two broad categories: **external tools** and **internal workloads**.


![Alt text](/images/37f.png)

---

### **Internal to the Cluster**

These are **Kubernetes-native agents and controllers** that run as Pods within the cluster. They communicate with the Kubernetes API server to **read, watch, or mutate** cluster resources as part of their function.


![Alt text](/images/37g.png)

#### **Examples**:

* **Monitoring agents** – Prometheus, Datadog Agent, New Relic
* **Logging agents** – Fluent Bit, Fluentd, Loki
* **Security scanners and defenders** – Trivy Operator, Aqua Security agents, Prisma Cloud defenders (in-cluster agents that scan images or monitor runtime behavior)
* **Policy enforcers** – Kyverno, Gatekeeper (OPA), Falco (runtime security and anomaly detection)
* **Metrics exporters** – Node Exporter, kube-state-metrics
* **GitOps controllers** – Argo CD, FluxCD. Argo CD has a built-in UI, commonly exposed via Ingress/LoadBalancer.

  > These tools run entirely **within the cluster**, poll Git repositories for changes, and apply the desired state to the cluster.
* **Backup controllers** – Velero controller, Stash operator

  > Manage and schedule backup/restore operations by interacting with Kubernetes resources and underlying storage systems.

---

> Many of these tools follow an **agent-controller model**:
>
> * **Agents inside the cluster** collect data, apply manifests, or enforce policies.
> * Data is often **pushed to an external system**, such as a dashboard, portal, or security console.
> * These external UIs typically **do not call the Kubernetes API themselves** — they rely on the data pushed by the agent.

---

### **Authentication Methods Used by Internal Workloads**

✅ **Projected ServiceAccount Tokens** (default method)

* Every Pod in Kubernetes is assigned a **ServiceAccount** (either default or explicitly set).

* A token for this ServiceAccount is **automatically projected** into the Pod at:

  ```
  /var/run/secrets/kubernetes.io/serviceaccount/token
  ```

* Starting from Kubernetes **v1.24**, these projected tokens are:

  * **Short-lived**
  * **Audience-bound** (i.e., meant for the Kubernetes API server)
  * **Signed by the control plane**

✅ **RBAC Controls Access**

* The ServiceAccount’s access to Kubernetes resources is defined via **RBAC roles and bindings**.
* Examples:

  * Prometheus may require `get`, `list`, `watch` on `endpoints`, `pods`, `services`.
  * Argo CD may need full control over Deployments, ConfigMaps, and Secrets.

> **Best Practice**: Use **custom ServiceAccounts with the minimum required RBAC permissions** per tool. Avoid giving broad access to the default ServiceAccount.

---

### **External to the Cluster**

These tools run **outside the Kubernetes cluster** but interact with the API server to deploy, configure, or query workloads.

![Alt text](/images/37h.png)

#### **Examples**:

* **CI/CD platforms** – Jenkins, GitLab CI/CD, GitHub Actions
* **Infrastructure automation** – Terraform, Pulumi, Ansible
* **Configuration management** – Chef, Puppet
* **Backup tooling (CLI components)** – Velero CLI, Stash CLI
* **Security scanners** – Trivy CLI, Prisma Cloud Console, Aqua CLI

> Note: Many of these tools **also deploy in-cluster agents** that perform actions and send telemetry or status to the external control plane.

---

### **Authentication Methods Used by External Tools**

✅ **Short-Lived ServiceAccount Tokens** (**Recommended for automation**)

* Kubernetes since 1.12 supports the **TokenRequest API** to issue **short-lived, scoped, and signed tokens** for a specific ServiceAccount.
* The token is passed using the `Authorization: Bearer <token>` header.
* Typically used by **CI/CD pipelines** or **automation frameworks** that trigger deployments or apply manifests.

✅ **Static Tokens or Client Certificates** (legacy or less secure)

* Some older workflows still use **long-lived tokens** or **TLS client certs** stored in `kubeconfig` files.
* These methods are less secure and harder to rotate.
* Should be phased out in favor of dynamic token requests.

---

### **TokenRequest API: Authentication Flow**

1. **External tool (e.g., Jenkins) requests a token** using the `TokenRequest` API for a specific ServiceAccount.
2. **Admin pre-creates the ServiceAccount** with required RBAC permissions and allows `create` on `serviceaccounts/token`.
3. **API server issues a signed JWT token**, which is short-lived, scoped to the ServiceAccount’s permissions, and bound to an audience.
4. **Tool uses the token** in the `Authorization: Bearer <token>` header to authenticate to the API server.
5. **When the token expires**, the tool must request a new one — tokens are not auto-renewed.

---

> **Best Practice**: Always prefer **short-lived tokens via TokenRequest API** for automated external tools. Avoid embedding long-lived secrets in scripts or pipelines.

---

### **Clarifying the Agent-Controller Model**

For tools that have both in-cluster and external components (such as Velero, Prisma Cloud, Argo CD):

* **In-cluster agents** handle all communication with the API server using projected ServiceAccount tokens.
* **External systems** (dashboards, consoles, CLIs) **do not call the API server directly**.
* Instead, the external UI consumes **data pushed by the agent** (e.g., via REST, gRPC, or webhook).
* This model eliminates the need for the external system to authenticate with the Kubernetes cluster directly.

In typical use cases, logging agents collect logs from the cluster and forward them to a centralized storage system such as Amazon S3 or CloudWatch Logs. Monitoring agents push metrics to a central monitoring system or a SaaS platform for analysis and alerting. Backup agents also send their status and results to a central dashboard that tracks backup success and failure.

Essentially, even though these agents run inside your Kubernetes cluster, their dashboards or user interfaces are usually hosted outside the cluster. These external interfaces are used for visualization, monitoring, and overall management.

---

## **Access Patterns Summary Table**

| Category                                 | Runs In  | Accesses API Server | Authentication Method                       | Example Tools                      |
| ---------------------------------------- | -------- | ------------------- | ------------------------------------------- | ---------------------------------- |
| **CI/CD pipelines**                      | External | Yes                 | Short-lived SA token via TokenRequest API   | GitLab CI, GitHub Actions, Jenkins |
| **Infrastructure automation**            | External | Yes                 | Short-lived SA token via TokenRequest API                        | Terraform, Pulumi, Ansible         |
| **Monitoring, Logging, Security Agents** | Internal | Yes                 | Projected ServiceAccount token              | Prometheus, Fluent Bit, Falco      |
| **Backup Controllers**                   | Internal | Yes                 | Projected ServiceAccount token              | Velero controller, Stash operator  |
| **GitOps Controllers**                   | Internal | Yes                 | Projected ServiceAccount token              | Argo CD, FluxCD                    |
| **Hybrid tools with external UI**        | Both     | Internal only       | Agents use SA; UI consumes pushed data only | Prisma Cloud, Velero, Argo CD      |

---

> **Note:** It doesn’t matter **who** is making the request (human or non-human) or **how** they’re making it — whether it’s through `kubectl`, `curl`, automation tools, or client libraries — **authentication is always performed by the Kubernetes API server**.
> Regardless of the method used (TLS certificates, bearer tokens, OIDC, webhook, or an authentication proxy), **every request hits the API server first**, and it is the one responsible for validating the identity behind that request.

---

## Demo: Creating and Using a ServiceAccount for Jenkins

### **Step 1: Create a Service Account for Jenkins**

First, define a **Service Account** for Jenkins in the `jenkins` namespace.

```bash
kubectl create ns jenkins
kubectl create sa jenkins-sa -n jenkins
```

---

### **Step 2: Create ClusterRole and ClusterRoleBinding for Jenkins SA**

Next, grant the ServiceAccount permissions by binding it to a ClusterRole:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-cluster-role
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"]
    verbs: ["get", "list", "watch", "create", "delete", "patch", "update"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "delete", "patch", "update"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-cluster-rolebinding
subjects:
  - kind: ServiceAccount
    name: jenkins-sa
    namespace: jenkins
    apiGroup: ""
roleRef:
  kind: ClusterRole
  name: jenkins-cluster-role
  apiGroup: rbac.authorization.k8s.io
```

Apply it:

```bash
kubectl apply -f jenkins-rbac.yaml
```

---

### **Step 3: Generate a Manual Long-Lived Token (Deprecated Approach)**

This step demonstrates **how Jenkins can initially use a manually created Service Account token**, though this method is **not recommended for production**.

1️⃣ **Create a Secret explicitly bound to the Service Account:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-sa-secret
  namespace: jenkins
  annotations:
    kubernetes.io/service-account.name: jenkins-sa
type: kubernetes.io/service-account-token
```

Apply it:

```bash
kubectl apply -f jenkins-sa-secret.yaml
```

2️⃣ **Retrieve the token from the Secret:**

```bash
kubectl describe -n jenkins secrets jenkins-sa-secret
```

This provides a **long-lived token** that Jenkins can **initially use** to authenticate.

⚠️ **Important:** Kubernetes **deprecated automatic long-lived token creation** in version **1.24+**. Instead, new service accounts now use **projected tokens**, which are **short-lived** and designed for improved security.

You can verify this token using [jwt.io](https://jwt.io) — it lacks an expiration claim.

---

### **Step 4: Jenkins Requests a Token Using the TokenRequest API (Recommended Approach)**

Instead of using a long-lived token, Jenkins can request a **short-lived token dynamically** via the TokenRequest API.

1️⃣ **Manually request a token for `jenkins-sa`:**

```bash
kubectl create token jenkins-sa --namespace=jenkins
```
also can use the `--duration=<>`

This returns an **ephemeral, audience-bound token** that Jenkins can use.

2️⃣ **Alternatively, send a direct API request for token generation:**

```bash
#Sidecar to rotate a token
TOKEN=$(kubectl get secret jenkins-sa-secret -n jenkins -o jsonpath="{.data.token}" | base64 --decode)

curl -X POST "https://<api-server-url>/api/v1/namespaces/jenkins/serviceaccounts/jenkins-sa/token" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
          "kind": "TokenRequest",
          "apiVersion": "authentication.k8s.io/v1",
          "spec": {
            "audiences": ["kubernetes"],
            "expirationSeconds": 3600
          }
        }'
```

This provides a **short-lived token** with a **1-hour expiration**.

---

### **Step 5: Jenkins Uses the Token to Authenticate**

Jenkins can use the generated token in API calls:

```bash
curl -H "Authorization: Bearer <TOKEN>" https://<api-server-url>/api/v1/pods -k
```

---

### **Key Takeaways**
✔️ **Manual token creation using Secrets is deprecated**—use **TokenRequest API instead**.  
✔️ **Projected tokens rotate automatically**, but external tools should request new tokens **dynamically**.  
✔️ **Best practice:** Jenkins should **request tokens when needed** instead of storing long-lived credentials.  

---

## Conclusion

**Mastering Kubernetes Service Accounts and authentication is paramount for building secure and robust cloud-native applications.** This document has illustrated that **all authentication, regardless of the requester or method, is centrally handled by the Kubernetes API server**. While various methods exist, from static files to sophisticated external identity providers, the shift towards **short-lived, projected Service Account tokens obtained via the TokenRequest API represents a significant security enhancement**. By adhering to the **principle of least privilege** and leveraging these modern authentication practices, especially for non-human interactions, administrators can significantly reduce security risks and improve the auditability of their Kubernetes environments.

--- 

## References
  * **Authenticating:** https://kubernetes.io/docs/reference/access-authn-authz/authentication/
  * **Service Accounts**: https://kubernetes.io/docs/concepts/security/service-accounts/


  



---
```bash
kubectl create namespace devops-tools

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-service-account
  namespace: devops-tools
EOF

cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: api-cluster-role
  namespace: devops-tools
rules:
  - apiGroups:
        - ""
        - apps
        - autoscaling
        - batch
        - extensions
        - policy
        - rbac.authorization.k8s.io
    resources:
      - pods
      - componentstatuses
      - configmaps
      - daemonsets
      - deployments
      - events
      - endpoints
      - horizontalpodautoscalers
      - ingress
      - jobs
      - limitranges
      - namespaces
      - nodes
      - pods
      - persistentvolumes
      - persistentvolumeclaims
      - resourcequotas
      - replicasets
      - replicationcontrollers
      - serviceaccounts
      - services
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: api-cluster-role-binding
subjects:
- namespace: devops-tools 
  kind: ServiceAccount
  name: api-service-account 
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: api-cluster-role 
EOF

kubectl auth can-i get pods --as=system:serviceaccount:devops-tools:api-service-account

kubectl auth can-i delete deployments --as=system:serviceaccount:devops-tools:api-service-account

# long live token

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: api-service-account-token
  namespace: devops-tools
  annotations:
    kubernetes.io/service-account.name: api-service-account
EOF

kubectl get secret api-service-account-token -o=jsonpath='{.data.token}' -n devops-tools | base64 --decode

kubectl get endpoints | grep kubernetes #Get the cluster endpoint to validate the API access. The following command will display the cluster endpoint (IP, DNS).

#Now that you have the cluster endpoint and the service account token, you can test the API connectivity using the CURL or the Postman app.

#For example, list all the namespaces in the cluster using curl. Use the token after Authorization: Bearer section.

curl -k  https://35.226.193.217/api/v1/namespaces -H "Authorization: Bearer eyJhbGcisdfsdfsdfiJ9.eyJpc3MiOisdfsdfVhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3sdf3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImFwaS1zZXJ2aWNlsdfglkjoer876Y3BmNWYiLsdfsdfRlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmFwaS1zZXJ2aWNlLWFjY291bnQifQ.u5jgk2px_lEs3f5e5lh_UfS40fndtDKMTY5UvsdfrtsuhtgjrUj-ezrRXeLS8SLOae4DuOGGGbInSg_gIo6oO7bLHhCixWOBJNOA5gzrLVioof_kHDR8gH5crrsWoR-GSSsdfgsdfg6fA_LDOqdxzqMC0WlXt6tgHfrwIHerPPvkI6NWLyCqX9tn_akpcihd-bL6GwOKlph17l_ND710FnTkE7kBfdXtQWWxaPPe06UEmoKK9t-0gsOCBxJxViwhHkvwqetr987q9enkadfgd_2cY_CA"
```