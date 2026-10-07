## **Kubernetes API: The Engine Behind Everything**

### **What Is the Kubernetes API?**

**Kubernete API server** is a interface for the clients to interact with the cluster.
**Kubernetes API Server** perform many functions Authentication, Authorizatioon, Admission control, and Hosting the **Kubernete APIs**(logically hosted).
**API Server** --> Physical componen--> pod,container,vm.
**Kubernetes API** --> Localical component hosted in the API server.
The **Kubernetes API** is the *primary interface* to your cluster. Whether you're creating a Pod, scaling a Deployment, or checking the status of a resource, you're interacting with this API.


It’s a **RESTful**, **resource-based interface** that exposes core Kubernetes objects like Pods, Services, Deployments, ConfigMaps, and more. These objects are accessible through structured URLs like `/api/v1` and `/apis/apps/v1`, and they respond to standard HTTP verbs like:

* **GET** – retrieve a resource
* **POST** – create a resource
* **PUT/PATCH** – update a resource
* **DELETE** – remove a resource

Anytime you use a tool like `kubectl`, it’s acting as a REST client that translates your CLI command into an API call.

Example:

```bash
kubectl get pods
```

translates to:

```http
GET /api/v1/namespaces/default/pods
```

This request is sent over **HTTPS**, authenticated using your **kubeconfig**, and authorized using cluster policies like **RBAC** or **Webhook authorization**.

---

**Kubernetes API vs. API Server**

Since the beginning of the course, we've said that the **API server is the central hub** of all Kubernetes communication — and that’s true. But it’s worth clarifying that the **Kubernetes API** is just **one part** of what the API server does.

The **Kubernetes API** refers specifically to the set of RESTful endpoints (like `/api`, `/apis`, `/healthz`, etc.) that expose cluster resources. It’s the interface used by internal components and external clients to read or modify the state of the cluster.

**RESTfull APIs** - https://www.geeksforgeeks.org/node-js/rest-api-introduction/

But the **API server itself** does much more than just serve API endpoints. It’s responsible for:

* **Authentication** (verifying who is making the request)
* **Authorization** (checking if the action is allowed)
* **Schema validation** (ensuring requests match expected formats)
* **Admission control** (enforcing cluster policies, which we’ll cover later)
* and much more..

So, in short:

> The **Kubernetes API is a logical interface** — the set of endpoints that represent your cluster's state.
> The **API server is the physical component** that hosts that API and applies all the control mechanisms around it.

This distinction helps frame the API server not just as a gateway to the cluster, but also as a **gatekeeper**, enforcing critical checks before anything gets stored in etcd.

---

### **Key Pointers**

To recap:

* The **Kubernetes API** is the **interface**, exposing your cluster's resources.
* The **API server** is the **component** that hosts this API and applies all access controls around it.
* Every request goes through a well-defined pipeline: **authentication → authorization → validation → execution**.
* Tools like `kubectl`, controllers, and even kubelets all communicate with your cluster through this same pathway.

Understanding this architecture gives you a clear mental model of how Kubernetes operates, enabling you to diagnose issues, secure your cluster, and build confidently atop its powerful API.

---

## **1. Kubernetes API Endpoints Overview**

![Alt text](/images/35c.png)

At a high level, the API server serves multiple paths. Each path corresponds to a different kind of functionality:

| **Endpoint**                    | **Description**                                                                                                                                                             |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/version`                      | Returns the version of the Kubernetes API server. **Unauthenticated and publicly accessible.**                                                                              |
| `/healthz`, `/livez`, `/readyz` | Health check endpoints for the **API server itself**, used by monitoring tools. `/livez` and `/readyz` are preferred in newer Kubernetes versions. **Unauthenticated and publicly accessible.** |
| `/api`                          | Root path for the **core API group** (`""` group), which includes legacy and foundational resources like Pods, Services, ConfigMaps, etc.                                   |
| `/apis`                         | Root path for all **named API groups** (e.g., `apps`, `rbac.authorization.k8s.io`, `networking.k8s.io`). Most modern resources live here.                                   |
| `/metrics`                      | Exposes **Prometheus-format** metrics that can be scraped by Prometheus or any monitoring system that supports the Prometheus exposition format. Prometheus.                                      |
| `/logs`                         | ❌ **Not a standalone API endpoint.** Accessing logs via `kubectl logs` invokes the `kubelet`’s `/containerLogs/` endpoint, not `/logs`. **`/logs`** is used by the API server to expose its own logs only when certain flags are enabled (e.g. --logtostderr=false, --log-dir)                                     |


### API Endpoints: Resource vs Non-Resource

The Kubernetes API is split across multiple **HTTPS endpoints**, each serving a different purpose:

* **Resource endpoints**
  These expose Kubernetes objects (Pods, Services, Deployments, etc.) and allow CRUD operations using standard HTTP verbs (GET, POST, PUT, DELETE).

  * `/api` → for **core group** resources (e.g., Pods, ConfigMaps, Services).
  * `/apis` → for **named group** resources (e.g., Deployments, Ingresses, Roles).

* **Non-resource endpoints**
  These do **not** expose Kubernetes objects but provide metadata or cluster-level utilities:

  * `/version` – Returns API server version.
  * `/healthz`, `/livez`, `/readyz` – Health check endpoints for the API server itself.
  * `/metrics` – Exposes API server metrics in **Prometheus format**.
  * `/logs` – Not a true API endpoint; `kubectl logs` reaches the kubelet, not the API server.


---

## API Groups: Organizing the Kubernetes API

Kubernetes organizes its API using **API groups**, enabling modular feature development and independent versioning. These are split into the **core group** and various **named groups**.

---

#### 1. **Core Group (`/api`)**

The **core group**—also called the legacy group—has no explicit group name and is served at `/api/v1`. It includes foundational objects essential to nearly every workload:

**Pods, Services, ConfigMaps, Secrets, Namespaces, PersistentVolumes (PVs), PersistentVolumeClaims (PVCs), ReplicationControllers**

When you use `apiVersion: v1` in a manifest, you're referencing this group.
Example: Pods can be listed via `/api/v1/pods`.

---

#### 2. **Named Groups (`/apis`)**

To prevent the core from becoming bloated, Kubernetes introduced **named API groups**, each representing a specific domain or extension. These are served at `/apis/GROUP/VERSION`.

Examples of named groups and associated resources:

* `apps/v1` → Deployments, StatefulSets, ReplicaSets
* `batch/v1` → Jobs, CronJobs
* `rbac.authorization.k8s.io/v1` → Roles, ClusterRoles, RoleBindings
* `autoscaling/v2` → HorizontalPodAutoscalers (HPA) with scaling policies
* `networking.k8s.io/v1` → Ingress, NetworkPolicies
* `policy/v1` → PodDisruptionBudgets, PodSecurityPolicies (deprecated)
* `certificates.k8s.io/v1` → CertificateSigningRequests (CSRs)
* `admissionregistration.k8s.io/v1` → ValidatingWebhookConfiguration, MutatingWebhookConfiguration
* `apiextensions.k8s.io/v1` → CustomResourceDefinitions (CRDs)
* `storage.k8s.io/v1` → StorageClasses, VolumeAttachments, CSI drivers

Each group version (like `apps/v1`) defines a versioned API surface. This ensures backward compatibility while allowing future versions to introduce breaking changes safely.


> You can find out which API group a resource belongs to by running:
>
> ```bash
> kubectl api-resources
> ```
>
> This command lists all resource types along with their associated **API group**, **namespaced scope**, and **short names**, helping you understand how Kubernetes organizes its resources.


```bash
======================== KUBERNETES API – COMPLETE PRACTICAL DEMO ========================

GOAL
- Prove that EVERYTHING in Kubernetes is an API call
- Interact directly with Kubernetes API (not kubectl magic)
- Understand resource vs non-resource endpoints
- Observe authentication + authorization in action

=======================================================================================

PREREQUISITES
-------------
- Working Kubernetes cluster
- kubectl configured
- Cluster-admin access (for learning)

=======================================================================================

STEP 1: CHECK API SERVER VERSION (NON-RESOURCE ENDPOINT)
--------------------------------------------------------
kubectl get --raw /version

Behind the scenes:
GET /version

Observation:
- No authentication error
- Public endpoint
- Returns:
  - gitVersion
  - goVersion
  - platform

CONFIRMATION:
✔ Non-resource endpoint
✔ Publicly accessible

=======================================================================================

STEP 2: CHECK API SERVER HEALTH
--------------------------------
kubectl get --raw /healthz
kubectl get --raw /livez
kubectl get --raw /readyz

Behind the scenes:
GET /healthz
GET /livez
GET /readyz

Observation:
- Returns "ok"
- Used by:
  - Load balancers
  - Monitoring tools

=======================================================================================

STEP 3: LIST API GROUPS
-----------------------
kubectl get --raw /api
kubectl get --raw /apis

/api   → core API group
/apis  → named API groups

CONFIRMATION:
✔ Kubernetes API is GROUPED and VERSIONED

=======================================================================================

STEP 4: EXPLORE CORE API RESOURCES
----------------------------------
kubectl get --raw /api/v1 | jq

You will see:
- pods
- services
- namespaces
- configmaps
- secrets
- nodes

CONFIRMATION:
✔ Core resources live under /api/v1

=======================================================================================

STEP 5: EXPLORE NAMED API GROUP (apps)
-------------------------------------
kubectl get --raw /apis/apps/v1 | jq

You will see:
- deployments
- statefulsets
- daemonsets
- replicasets

CONFIRMATION:
✔ Modern workloads live under /apis

=======================================================================================

STEP 6: CREATE A POD (RESOURCE ENDPOINT)
---------------------------------------
kubectl run api-demo-pod --image=nginx

Behind the scenes:
POST /api/v1/namespaces/default/pods

CONFIRMATION:
✔ kubectl → REST call → API server

=======================================================================================

STEP 7: FETCH PODS USING RAW API
--------------------------------
kubectl get --raw /api/v1/namespaces/default/pods | jq '.items[].metadata.name'

CONFIRMATION:
✔ Direct API interaction
✔ JSON response

=======================================================================================

STEP 8: DELETE POD USING API
----------------------------
kubectl delete pod api-demo-pod

Behind the scenes:
DELETE /api/v1/namespaces/default/pods/api-demo-pod

=======================================================================================

STEP 9: AUTHENTICATION FAILURE DEMO
-----------------------------------
Use curl WITHOUT token:

API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

curl -k $API_SERVER/api

Result:
401 Unauthorized

CONFIRMATION:
✔ API server enforces authentication

=======================================================================================

STEP 10: AUTHENTICATION SUCCESS WITH TOKEN
------------------------------------------
Extract token from kubeconfig:

TOKEN=$(kubectl config view --minify -o jsonpath='{.users[0].user.token}')

curl -k \
  -H "Authorization: Bearer $TOKEN" \
  $API_SERVER/api

Result:
- API versions returned

CONFIRMATION:
✔ Authentication succeeded

=======================================================================================

STEP 11: AUTHORIZATION FAILURE DEMO (RBAC)
------------------------------------------
Create limited ServiceAccount:

kubectl create sa api-test

Try accessing pods using its token (no RBAC yet):
→ 403 Forbidden

CONFIRMATION:
✔ Authenticated
✔ Not authorized

=======================================================================================

STEP 12: RBAC FIX
-----------------
kubectl create role pod-reader \
  --verb=get,list \
  --resource=pods

kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=default:api-test

Retry API call → SUCCESS

=======================================================================================

STEP 13: NON-RESOURCE RBAC DEMO
--------------------------------
RBAC rule example:
nonResourceURLs:
- /healthz
- /version

Shows:
✔ Resource & non-resource endpoints are controlled separately

=======================================================================================

REQUEST FLOW YOU JUST PROVED
-----------------------------
Client (kubectl/curl)
 → API Server
 → Authentication
 → Authorization
 → Admission
 → Validation
 → etcd

=======================================================================================

REAL-WORLD TAKEAWAY
-------------------
- Kubernetes is API-driven
- kubectl is just a REST client
- API server is the gatekeeper
- RBAC controls everything
- If you understand the API, you understand Kubernetes

=======================================================================================

ONE-LINE SUMMARY
----------------
No API request → No Kubernetes action.

=======================================================================================
```

---


### Why the Core Group Name Isn’t Shown in Manifests

When Kubernetes was first introduced, it had only one group of resources—what we now call the **core group**. These resources (like Pods, Services, and ConfigMaps) were served at the path `/api/v1`. Because there was only one group, manifests used a simple format:

```yaml
apiVersion: v1
```

As Kubernetes evolved, **named API groups** were introduced to support new features and better organize resources. These use a different URL pattern (`/apis/GROUP/VERSION`) and must include both the group and version in manifests, such as:

```yaml
apiVersion: apps/v1
```

To maintain **backward compatibility**, Kubernetes did **not modify the syntax** for the original core resources. That’s why:

* Resources in the **core group** still use `apiVersion: v1`, without a group name.
* Resources in **named groups** always specify both group and version, like `rbac.authorization.k8s.io/v1`.

> Technically, the core group **does have a name**—it’s an **empty string (`""`)**—but it's **not shown** in YAML files or API paths.

This historical decision keeps older manifests valid while supporting Kubernetes' growing ecosystem.

#### Why don’t we write `apiVersion: /api/v1` or `apiVersion: apis/networking.k8s.io/v1`?

Because the `apiVersion` field in YAML **does not mirror the full HTTP URL**. Instead, it just identifies the **group and version**:

* For **core group** resources, the group is an empty string `""`, so we write:

  ```yaml
  apiVersion: v1
  ```
* For **named group** resources like NetworkPolicy, we include both group and version:

  ```yaml
  apiVersion: networking.k8s.io/v1
  ```

This design separates manifest readability from URL structure while maintaining backward compatibility. The API server internally maps the `apiVersion` to the correct endpoint (`/api/v1` or `/apis/<group>/<version>`).

---

### Accessing Unauthenticated and Authenticated Kubernetes API Endpoints via `curl`

Kubernetes exposes some **unauthenticated endpoints** that can be accessed without authentication—mostly used for health checks and cluster metadata.

#### Unauthenticated Endpoints

These endpoints are useful for introspection and liveness/readiness probes:

* `/version` – Returns the API server version
* `/readyz` – Reports API server readiness
* `/livez` – Reports API server liveness
* `/healthz` – Legacy endpoint for health status

##### Steps to Access:

1. **Get your API server address**:
   ```bash
   kubectl config view --minify
   ```

2. **Try accessing the version endpoint directly**:
   ```bash
   curl https://127.0.0.1:53856/version
   ```

   This may fail with a TLS error because the API server presents a certificate signed by a cluster-specific CA your system does not trust.

    ```bash
    curl: (60) SSL certificate problem: unable to get local issuer certificate
    More details here: https://curl.se/docs/sslcerts.html

    curl failed to verify the legitimacy of the server and therefore could not
    establish a secure connection to it. To learn more about this situation and
    how to fix it, please visit the web page mentioned above.
    ```

3. **Skip certificate verification** (not recommended in production):
   ```bash
   curl -k https://127.0.0.1:53856/version
   {
    "major": "1",
    "minor": "34",
    "emulationMajor": "1",
    "emulationMinor": "34",
    "minCompatibilityMajor": "1",
    "minCompatibilityMinor": "33",
    "gitVersion": "v1.34.1",
    "gitCommit": "93248f9ae092f571eb870b7664c534bfc7d00f03",
    "gitTreeState": "clean",
    "buildDate": "2025-09-09T19:37:20Z",
    "goVersion": "go1.24.6",
    "compiler": "gc",
    "platform": "linux/amd64"
    }
   ```
   OR
   ```bash
   curl --cacert /etc/kubernetes/pki/ca.crt \
   --cert seema.crt \
   --key seema.key \
   https://172.30.1.2:6443/version

   curl --cacert /etc/kubernetes/pki/ca.crt \
   https://172.30.1.2:6443/version
   ```

   You can use the same `-k` flag for:
   ```bash
   curl -vk https://127.0.0.1:53856/readyz
   curl -vk https://127.0.0.1:53856/livez
   curl -vk https://127.0.0.1:53856/healthz
   ```

   If the API server is healthy, these endpoints return:
   ```
   ok
   ```

---

#### Authenticated API Access Using curl

To access secure endpoints like `/api` or `/apis`, you must authenticate using the certificates provided in your kubeconfig. Here's how you can do it using `curl`:

```bash
curl https://127.0.0.1:53856/api \                   # API server endpoint
  --cert client.crt \                                # Your client certificate
  --key client.key \                                 # Your client private key
  --cacert ca.crt                                    # The CA that signed the API server’s certificate
```

> ⚠️ Make sure these certificate files are properly extracted from your kubeconfig and **base64 decoded** before use.

Do the same for:

* `client.key` (if embedded in kubeconfig, decode and dump)
* `ca.crt` (you can also extract it from the `certificate-authority-data` field)

---


#### Note on Bearer Tokens

Instead of using certificates, you can also authenticate using **bearer tokens**—these are commonly issued to service accounts or users. We’ll cover bearer token authentication later in this course.

---

```text
==================== KUBERNETES CORE API GROUP & API ACCESS – PRACTICAL DEMO ====================

GOAL
- Understand why core group has no name in manifests
- Prove how apiVersion maps to real API endpoints
- Access Kubernetes API using curl
- See unauthenticated vs authenticated endpoints in action

===============================================================================================

PART 1: WHY CORE GROUP HAS NO NAME (PRACTICAL PROOF)
----------------------------------------------------

STEP 1: List API groups exposed by the cluster
----------------------------------------------
kubectl api-versions

Observation:
- You will see:
  v1
  apps/v1
  networking.k8s.io/v1
  rbac.authorization.k8s.io/v1
  ...

IMPORTANT:
- `v1` alone = CORE GROUP
- Others = named groups

===============================================================================================

STEP 2: List core resources
---------------------------
kubectl api-resources --api-group=""

You will see:
- pods
- services
- configmaps
- secrets
- nodes

CONFIRMATION:
✔ Core group name = empty string ""

===============================================================================================

STEP 3: Compare manifest examples
---------------------------------

Core group (Pod):
apiVersion: v1
kind: Pod

Named group (Deployment):
apiVersion: apps/v1
kind: Deployment

WHY?
- Core group existed first
- Backward compatibility preserved
- Group name is implicitly ""

===============================================================================================

PART 2: PROVE URL MAPPING (apiVersion → API PATH)
-------------------------------------------------

STEP 4: Access core API endpoint
--------------------------------
kubectl get --raw /api/v1 | jq '.resources[].name'

This maps to:
apiVersion: v1

===============================================================================================

STEP 5: Access named API group endpoint
---------------------------------------
kubectl get --raw /apis/networking.k8s.io/v1 | jq '.resources[].name'

This maps to:
apiVersion: networking.k8s.io/v1

CONFIRMATION:
✔ apiVersion ≠ full URL
✔ API server maps internally

===============================================================================================

PART 3: ACCESS UNAUTHENTICATED ENDPOINTS USING curl
---------------------------------------------------

STEP 6: Get API server endpoint
-------------------------------
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'

Example:
https://127.0.0.1:53856

Save it:
API_SERVER=https://127.0.0.1:53856

===============================================================================================

STEP 7: Access /version (unauthenticated)
-----------------------------------------
curl $API_SERVER/version

Expected:
❌ TLS error (unknown CA)

Fix (skip verification – demo only):
curl -k $API_SERVER/version

Result:
✔ Kubernetes version info returned

===============================================================================================

STEP 8: Access health endpoints
--------------------------------
curl -k $API_SERVER/readyz
curl -k $API_SERVER/livez
curl -k $API_SERVER/healthz

Expected:
ok

CONFIRMATION:
✔ These endpoints are public
✔ Used for health checks

===============================================================================================

PART 4: FAILING AUTHENTICATED ENDPOINT (EXPECTED)
-------------------------------------------------

STEP 9: Try accessing /api without auth
---------------------------------------
curl -k $API_SERVER/api

Result:
401 Unauthorized

CONFIRMATION:
✔ Authentication is enforced

===============================================================================================

PART 5: AUTHENTICATED API ACCESS USING CERTS
--------------------------------------------

STEP 10: Extract cert paths from kubeconfig
-------------------------------------------
kubectl config view --minify

Look for:
- client-certificate-data
- client-key-data
- certificate-authority-data

Decode them:
(base64 decode into files)

Example:
echo "<base64>" | base64 -d > client.crt
echo "<base64>" | base64 -d > client.key
echo "<base64>" | base64 -d > ca.crt

===============================================================================================

STEP 11: Access API using client certificates
---------------------------------------------
curl $API_SERVER/api \
  --cert client.crt \
  --key client.key \
  --cacert ca.crt

Result:
✔ API versions returned

CONFIRMATION:
✔ Authenticated access succeeded

===============================================================================================

PART 6: AUTHENTICATED ACCESS USING BEARER TOKEN
-----------------------------------------------

STEP 12: Extract token from kubeconfig
--------------------------------------
kubectl config view --minify -o jsonpath='{.users[0].user.token}'

Save it:
TOKEN=<token>

===============================================================================================

STEP 13: Use bearer token with curl
-----------------------------------
curl -k $API_SERVER/api \
  -H "Authorization: Bearer $TOKEN"

Result:
✔ API response returned

===============================================================================================

WHAT YOU JUST PROVED
--------------------
✔ Core group has empty name ""
✔ apiVersion is NOT a URL
✔ API server maps apiVersion → endpoint
✔ Some endpoints are public
✔ Resource APIs require authentication
✔ kubeconfig is just API credentials
✔ kubectl is a REST client

===============================================================================================

MENTAL MODEL (REMEMBER THIS)
----------------------------
Manifest apiVersion
→ API group + version
→ API server endpoint
→ Authentication
→ Authorization
→ Admission
→ etcd

===============================================================================================

FINAL TAKEAWAY
--------------
The Kubernetes API is the contract.
The API server is the gatekeeper.
The core group looks special only because it came first.

===============================================================================================

END OF PRACTICAL
===============================================================================================

If you want next:
- RBAC for nonResourceURLs
- Admission controller demo
- API audit logging walkthrough
- CKA / CKS exam-style questions
```


---

## **Bonus: Understanding API Paths**

The Kubernetes API is **RESTful and resource-based**. It uses standard HTTP verbs like `GET`, `POST`, `PUT`, `DELETE`, etc.

The general structure is:

```
/<root>/<group>/<version>/namespaces/<namespace>/<resourceType>/<name>
```

Examples:

* `GET /api/v1/namespaces/default/pods` – List Pods (core group)
* `POST /apis/apps/v1/namespaces/prod/deployments` – Create a Deployment (apps group)
* `GET /apis/rbac.authorization.k8s.io/v1/clusterroles/admin` – Get a ClusterRole (non-namespaced)

---

### **Key Points:**

* The Kubernetes API is RESTful, structured by resource type, and serves both human and machine clients.
* `/api` is for core group resources (pods, services), `/apis` is for named group resources (deployments, jobs).
* API groups help manage evolution and ownership of functionality.
* `apiVersion` in YAML manifests maps directly to these groups and versions.
* Use `kubectl`, `curl`, or client libraries to interact with the API.
* The API is extensible using CRDs or aggregated services. CRDs & extensibility to be discussed later in this course.