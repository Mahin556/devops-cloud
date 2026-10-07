* The kubeconfig file is used to access Kubernetes clusters, mainly by the kubectl command-line tool.
* Kubernetes components like `kubelet`, `kube-controller-manager`, or `kubectl` use the kubeconfig file to interact with the Kubernetes API. Usually, the `kubectl` or oc commands use the kubeconfig file.
* Especially in environments that involve multiple clusters and namespaces, managing access securely and efficiently becomes crucial. 
* The default location of the kubeconfig file is: `$HOME/.kube/config`
* In `kubeconfig` PEM format certiticates should be stored in a BASE64 format.
* You can specify a custom kubeconfig file using:
```bash
KUBECONFIG=<path>
--kubeconfig <path>

KUBECONFIG=/my/kubeconfig kubectl get pods
kubectl get pods --kubeconfig /my/kubeconfig

export KUBECONFIG=/my/kubeconfig
kubectl get pods
```

---

## Kubeconfig and Kubernetes Context

### What is a Kubeconfig File and Why Do We Need It?

![Alt text](/images/31-9.png)

* The **kubeconfig file** is a configuration file that stores:

  * **Cluster connection information** (e.g., API server URL)
  * **User credentials** (e.g., authentication tokens, certificates)
  * **Context information** (e.g., which cluster and user to use)
* It allows Kubernetes tools (like `kubectl`) to interact with the cluster securely and seamlessly.
* The kubeconfig file simplifies authentication and access control, eliminating the need to manually provide connection details each time we run a command.

### What If the Kubeconfig File Were Not There?

Without the kubeconfig file, you would need to manually specify the cluster connection information for every command. For example:

* With the kubeconfig file:

  ```bash
  kubectl get pods
  ```

* Without the kubeconfig file, you would need to include details like this:

  ```bash
  kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d > client-certificate-data.crt

  kubectl config view --raw -o jsonpath='{.users[0].user.client-key-data}' | base64 -d > client-key-data.key

  kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > certificate-authority-data.crt

  kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}';echo
  https://172.30.1.2:6443

  # We need to use this long flags

  curl https://your-api-server.com/api/v1/namespaces/default/pods \
  --cacert ca.crt \
  --cert user.crt \
  --key user.key

  kubectl get pods \
    --server=https://<API_SERVER_URL> \
    --certificate-authority=<CA_CERT_FILE> \
    --client-key=<CLIENT_KEY_FILE> \
    --client-certificate=<CLIENT_CERT_FILE>

  kubectl get pods \
    --server=https://172.30.1.2:6443 \
    --certificate-authority=certificate-authority-data.crt \
    --client-key=client-key-data.crt \
    --client-certificate=client-certificate-data.crt

  KUBECONFIG=/dev/null kubectl \
   --server=https://172.30.1.2:6443 \ 
   --certificate-authority=certificate-authority-data.crt \
   --client-key=client-key-data.key \
   --client-certificate=client-certificate-data.crt \
   get pods
  ```

As you can see, without the kubeconfig file, the command becomes longer and more error-prone. Each command requires explicit details, which can be tedious to manage.

**We will look into how a kubeconfile looks like in a while.**

# 🔍 Deep Dive: Anatomy of a `kubeconfig` File

The **kubeconfig** file is what lets `kubectl` (or any Kubernetes client) know:

* Which **cluster** to talk to
* Which **user** (credentials/certificate) to use
* Which **context** (user + cluster + namespace) is active

It’s typically found at:

```bash
~/.kube/config
```

---

## 🧩 High-Level Structure

```yaml
apiVersion: v1

clusters:
- name: dev-cluster
  cluster:
    server: https://api.dev.k8s.local:6443
    certificate-authority-data: <base64 CA cert>

users:
- name: sema
  user:
    client-certificate-data: <base64 user cert>
    client-key-data: <base64 user private key>

contexts:
- name: sema@dev-cluster
  context:
    cluster: dev-cluster
    user: sema
    namespace: app1-dev-ns

current-context: sema@dev-cluster
```

---

## 🧱 Sections Breakdown

### 1️⃣ `clusters` section

Defines which Kubernetes clusters exist and how to connect to them.

**Fields:**

* `name`: Friendly name for the cluster (e.g., `dev-cluster`)
* `server`: API server endpoint (e.g., `https://1.2.3.4:6443`)
* `certificate-authority-data`: Base64-encoded **CA certificate** used to verify the API server’s identity

**Purpose:**
When `kubectl` connects, it checks the **API server certificate** against this **CA** to ensure authenticity.

📘 **Analogy:**
When you visit a website over HTTPS, your browser uses a CA certificate to verify the site’s TLS certificate — same logic here.

---

### 2️⃣ `users` section

Defines **who** is making the request — their credentials (usually certificate-based).

**Fields:**

* `name`: User identifier (e.g., `sema`)
* `client-certificate-data`: Base64-encoded **certificate** for the user
* `client-key-data`: Base64-encoded **private key** of the user

**Purpose:**
Used for **mutual TLS (mTLS)** — both client and server verify each other.

📘 **Analogy:**
Think of this like showing your ID card (certificate) signed by an authority (CA) that the cluster trusts.

> ⚠️ The private key is never transmitted — it stays local and signs challenges to prove identity.

---

### 3️⃣ `contexts` section

Defines a **mapping** between:

* A cluster
* A user
* A default namespace

**Fields:**

* `name`: Context name (`user@cluster`)
* `cluster`: Refers to one defined under `clusters`
* `user`: Refers to one defined under `users`
* `namespace`: Default namespace for `kubectl` commands

**Purpose:**
Allows easily switching between multiple environments (e.g., dev, staging, prod) using:

```bash
kubectl config use-context sema@staging-cluster
```

---

### 4️⃣ `current-context`

Specifies which context is currently **active** — i.e., which cluster/user pair `kubectl` commands target by default.

```yaml
current-context: sema@dev-cluster
```

Run:

```bash
kubectl config current-context
```

to check it.

---

## 🔒 How Certificates Work in kubeconfig (mTLS Handshake)

Let’s connect it to the diagram from your transcript.

```
┌────────────────────┐         ┌────────────────────────┐
│ kubectl (client)   │         │ K8s API Server         │
│ User: Sema         │         │ Cluster: dev-cluster   │
└──────┬─────────────┘         └────────┬───────────────┘
       │ 1. Connect to API Server (from 'server' field)
       │ 2. Server presents its certificate
       ▼
       🔍 kubectl verifies API server’s cert using
          'certificate-authority-data' (CA cert)
       │
       │ 3. Client presents its own certificate
       ▼
       🔒 API Server verifies client's cert
          against Kubernetes CA (in cluster)
       │
       └── 4. Mutual trust established (mTLS)
```

So:

* `certificate-authority-data` → helps **client trust the server**
* `client-certificate-data` + `client-key-data` → help **server trust the client**

---

## 🧠 Base64 Encoding Reminder

* All certificate and key data in kubeconfig are **Base64-encoded**, not encrypted.
* Encoding = representation, not protection.
* Anyone with read access to kubeconfig can impersonate the user — so secure this file properly.

---

## 🧩 Example: Multiple Clusters and Contexts

```yaml
clusters:
- name: dev
  cluster:
    server: https://dev.k8s.local:6443
    certificate-authority-data: <CA-dev>
- name: staging
  cluster:
    server: https://staging.k8s.local:6443
    certificate-authority-data: <CA-staging>

users:
- name: sema
  user:
    client-certificate-data: <user-cert>
    client-key-data: <user-key>

contexts:
- name: sema@dev
  context:
    cluster: dev
    user: sema
    namespace: app1-dev-ns
- name: sema@staging
  context:
    cluster: staging
    user: sema
    namespace: app1-stage-ns

current-context: sema@dev
```

Switching between environments:

```bash
kubectl config use-context sema@staging
```

---

## ⚙️ Commands You Should Know

| Command                                | Description                     |
| -------------------------------------- | ------------------------------- |
| `kubectl config view`                  | Show entire config              |
| `kubectl config get-contexts`          | List all contexts               |
| `kubectl config current-context`       | Show current active context     |
| `kubectl config use-context <context>` | Switch context                  |
| `kubectl config set-context`           | Create/modify a context         |
| `kubectl config set-cluster`           | Add or modify a cluster         |
| `kubectl config set-credentials`       | Add or modify a user credential |

---

## 📘 Summary

| Component           | Purpose                         | Example Field                                |
| ------------------- | ------------------------------- | -------------------------------------------- |
| **Cluster**         | Defines API server & CA         | `server`, `certificate-authority-data`       |
| **User**            | Defines credentials             | `client-certificate-data`, `client-key-data` |
| **Context**         | Maps user → cluster → namespace | `context`                                    |
| **Current-context** | Default connection              | `sema@dev-cluster`           

---

# **Flow: How `kubectl` Uses kubeconfig (mTLS Authentication)**

---

## 🧩 Components Involved

| Component                      | Description                                                |
| ------------------------------ | ---------------------------------------------------------- |
| **kubectl / client**           | The command-line tool used to communicate with the cluster |
| **kubeconfig file**            | Holds all connection info: clusters, users, contexts       |
| **API Server**                 | The Kubernetes control plane entry point                   |
| **Certificate Authority (CA)** | The trusted signer for server and client certificates      |

---

## 🔁 Step-by-Step Flow

```
[User] → runs a kubectl command
```

### **Step 1: Load kubeconfig**

👉 kubectl first reads the kubeconfig file from:

```
~/.kube/config
```

It identifies:

* `current-context` (e.g., `sema@dev-cluster`)
* Which **user**, **cluster**, and **namespace** to use.

---

### **Step 2: Extract connection info**

From the selected context, kubectl gets:

* API server endpoint (`server`)
* Cluster CA certificate (`certificate-authority-data`)
* Client certificate and private key (`client-certificate-data`, `client-key-data`)

---

### **Step 3: Start TLS handshake**

kubectl initiates a secure connection to the **API server** defined in the cluster section.

```
kubectl  ⇄  API Server
```

Both will now perform **mutual TLS authentication**.

---

### **Step 4: Server presents its certificate**

* The API server sends its **TLS certificate** (signed by Kubernetes CA).
* kubectl uses the **CA certificate** (from `certificate-authority-data`) to **verify**:

  * The certificate’s signature is valid
  * The CN (Common Name) or SAN matches the expected API server name

✅ If valid → client trusts the server.
❌ If invalid → connection fails with “certificate not trusted.”

---

### **Step 5: Client presents its certificate**

Now the API server asks the client to prove its identity.

* kubectl sends its **client certificate** (from `client-certificate-data`)
* API server checks:

  * Is it signed by a CA the cluster trusts?
  * Is the user authorized (via RBAC) to perform this action?

✅ If valid → server trusts the client.
❌ If invalid → “Unauthorized” or “certificate signed by unknown authority.”

---

### **Step 6: mTLS established**

At this point, **mutual trust** is built.

✅ Both sides are verified using certificates
🔐 Secure TLS channel is established

Now kubectl can safely send API requests.

---

### **Step 7: Send API request**

kubectl sends REST API requests (e.g., `GET /api/v1/pods`) over the encrypted channel.

API server checks:

* The authenticated **user identity** (from the certificate CN or O fields)
* RBAC policies to authorize the action

Then returns the response.

---

### **Step 8: Display Output**

kubectl displays the result in your terminal, e.g.:

```
NAME      READY   STATUS    AGE
app-pod   1/1     Running   2m
```

---

## 🧠 **Visual Summary**

```
┌─────────────────────────────┐
│      ~/.kube/config         │
│-----------------------------│
│ current-context: sema@dev   │
│ users: [Sema’s cert + key]  │
│ clusters: [API server + CA] │
└────────────┬────────────────┘
             │
1️⃣ kubectl reads config
             │
2️⃣ Connect to API server
             │
3️⃣ Server → presents certificate
             │
4️⃣ kubectl verifies using CA cert
             │
5️⃣ kubectl → presents client certificate
             │
6️⃣ API server verifies using Kubernetes CA
             │
7️⃣ Mutual TLS (mTLS) established 🔒
             │
8️⃣ Authorized → Execute request
```

---

## 🧩 Bonus: Kubernetes CAs in This Flow

Inside the cluster:

* **Kubernetes CA** = root CA for signing:

  * API Server certificate
  * Kubelet client/server certs
  * Controller Manager certs
  * Client certificates for users or services (like `kubectl`)

That’s why the **CA public certificate** is embedded inside your kubeconfig — so your local client can trust the API server it’s talking to.

---

### ✅ **Summary Flow Table**

| Step | Action                      | Who Performs It | Purpose                  |
| ---- | --------------------------- | --------------- | ------------------------ |
| 1    | Load kubeconfig             | kubectl         | Get connection info      |
| 2    | Connect to API server       | kubectl         | Start TLS handshake      |
| 3    | Server presents certificate | API Server      | Prove server identity    |
| 4    | Verify server certificate   | kubectl         | Trust the server         |
| 5    | Present client certificate  | kubectl         | Prove client identity    |
| 6    | Verify client certificate   | API Server      | Trust the client         |
| 7    | Establish mTLS              | Both            | Secure encrypted channel |
| 8    | Send/receive API requests   | Both            | Operate cluster securely |
