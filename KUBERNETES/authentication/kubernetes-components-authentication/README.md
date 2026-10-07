## **Kubernetes components authenticate and trust each other using TLS**


* How **Private CAs** work inside Kubernetes clusters
* Which components act as **clients vs. servers**
* And how to decode **real-world mTLS setups** without memorizing paths

We'll walk through examples like the **Scheduler ↔ API Server**, **API Server ↔ etcd**, and **API Server ↔ Kubelet**, inspecting actual certs and config files to see how TLS and authentication work in practice.

---

### **Private CAs in Kubernetes Clusters**

![Alt text](/images/33b.png)

In Kubernetes, **TLS certificates secure communication** between core components. These certificates are signed by a **private Certificate Authority (CA)**, ensuring authentication and encryption. Depending on security requirements, a cluster can be configured to use:

* A **single CA** for the entire cluster (simpler, easier to manage), or
* **Multiple CAs** (e.g., a separate CA for etcd) for added security and isolation.

**Why Use Multiple CAs?**

Using **multiple private CAs** strengthens security by **isolating trust boundaries**. This approach is particularly useful for sensitive components like **etcd**, which stores the **entire cluster state**.

Multiple CAs used to provide isolation and isolation reduce the attack surface just like creating a multiple AWS accounts in case if one account got compromised and account one is stay without any impact(decoupling).

Security Considerations:
- If **etcd is compromised**, an attacker could gain full control over the cluster.
- To **limit the blast radius** in case of a CA or key compromise, it's common to **assign a separate CA exclusively for etcd**.
- Other control plane components (e.g., API server, scheduler, controller-manager) can share a **different CA**, ensuring **compartmentalized trust**.

By segmenting certificate authorities, Kubernetes operators can **reduce risk** and **enhance security posture**.

```bash
Security Consideration: Why Kubernetes Uses Multiple Certificate Authorities (CAs)

Kubernetes separates certificates into different Certificate Authorities (CAs) to limit blast radius and contain security breaches. If a single CA were used for everything, compromising that CA would compromise the *entire* cluster. Here's why separating CAs matters:

1. etcd has its own CA because:
   - etcd stores ALL cluster state (Secrets, ConfigMaps, RBAC rules, ServiceAccounts).
   - If an attacker breaks into etcd or steals the etcd CA, they can directly read/write any value.
   - A dedicated CA ensures that even if etcd is compromised, other components like the API server or nodes cannot be impersonated.

2. Kube-apiserver, scheduler, controller-manager share a different CA because:
   - These control-plane components talk to each other frequently.
   - If the CA used for control-plane components is compromised, etcd still remains protected by its separate CA.
   - This isolates trust boundaries: control plane compromise ≠ automatic etcd compromise.

3. Kubelet/server/front-proxy certificates often use different CAs because:
   - Kubelets authenticate workloads and nodes; compromising this CA allows node impersonation.
   - Front-proxy CA secures aggregated APIs; compromising this CA only affects extension APIs, not the core API server.

Real Practical Scenario:
- If someone steals the etcd CA private key:
  → They can impersonate the API server to etcd.
  → They can read all secrets and modify cluster state.
  BUT they cannot impersonate kubelets or aggregated APIs if those use separate CAs.

- If someone steals the kubelet CA:
  → They can impersonate nodes.
  BUT cannot read/modify etcd secrets, because etcd uses a different CA.

This CA separation limits damage to only one "trust domain" at a time, instead of collapsing the whole cluster when one key leaks.
```

You can configure Kubernetes components to **trust a private CA** by distributing the CA’s public certificate to each component’s trust store. For example:

* `kubectl` trusts the API server because it has the **private CA** certificate that signed the API server's certificate.
* Similarly, components like the `controller-manager`, `scheduler`, and `kubelet` trust the API server and each other using certificates signed by this **shared private CA**.

Most Kubernetes clusters—whether provisioned via tools like `kubeadm`, `k3s`, or through managed services like **EKS**, **GKE**, or **AKS**—automatically generate and manage a **private CA** during cluster initialization. This CA is used to issue certificates for key components, enabling **TLS encryption and mutual authentication** out of the box.

When using **managed Kubernetes services**, this private CA is maintained by the cloud provider. It remains **hidden from users**, but all internal components are configured to trust it, ensuring secure communication without manual intervention.

However, when setting up a cluster **“the hard way”** (e.g., via [Kelsey Hightower’s guide](https://github.com/kelseyhightower/kubernetes-the-hard-way)), **you are responsible for creating and managing the entire certificate chain**. This means:

* Generating a root CA certificate and key,
* Signing individual component certificates,
* And distributing them appropriately.

While this approach offers **maximum transparency and control**, it also demands a solid understanding of **PKI, TLS, and Kubernetes internals**.

![](/images/image-cas.png)

---

**Do Enterprises Use Public CAs for Kubernetes?**

Enterprises do **not** use public Certificate Authorities (CAs) for **core Kubernetes internals**. Instead, they rely on **private CAs**—either auto-generated (using tools like `kubeadm`) or centrally managed—to sign certificates used by Kubernetes components like the API server, kubelet, controller-manager, and scheduler. These certificates facilitate secure **TLS encryption and mutual authentication** within the cluster.

For **public-facing services**, however, it's common to use **public CAs**. Components such as:

* Ingress controllers
* Load balancers
* Gateway API implementations

...require certificates trusted by browsers. In these cases, enterprises use public CAs (e.g., Let’s Encrypt, DigiCert, GlobalSign) to issue TLS certificates, ensuring a secure **HTTPS** experience for users and avoiding browser trust warnings.

In short:

* **Private CAs** → Used for internal Kubernetes communication
* **Public CAs** → Used for securing external-facing applications
* ⚠️ Public CAs are **not** used for control plane or internal Kubernetes components
---

### Kubernetes Components as Clients and Servers

In the diagram below, arrows represent the direction of client-server communication:

![Alt text](/images/33a.png)

* The **arrow tail** indicates the **client**, and the **arrowhead** points to the **server**.
* Some arrows have **only arrowheads** (e.g., between **kubelet** and **API server**) to indicate that **the server initiates the connection** in specific cases:

  * When a user runs commands like `kubectl logs` or `kubectl exec`, the **API server acts as the client**, reaching out to the **kubelet**.
  * Conversely, when the **kubelet pushes node or pod health data**, it becomes the **client**, and the **API server** is the **server**.
* The **etcd arrow is colored yellow** to indicate that **etcd always acts as a server**, receiving requests from the API server.

---

### **Client (Initiates a Request)**

1. **kubectl**: **Interacts with the API server**, used by admins and DevOps engineers for cluster management, deployment, viewing logs.
2. **Scheduler**: **Requests the API server** for pod scheduling, checks for unscheduled pods, manages resource placement.
3. **API Server**: **Communicates with etcd**, **interacts with kubelet** for logs, exec commands, etc.
4. **Controller Manager**: **Requests the API server** to verify desired vs. current state, manages controllers, ensures cluster state matches desired configuration.
5. **Kube-Proxy**: **Communicates with the API server** for service discovery and endpoints, acts as a network router for traffic.
6. **Kubelet**: **Reports to the API server** about node health and pod status, fetches ConfigMaps & Secrets, ensures desired containers are running.

---
### **Server (Responds to the Request)**

1. **API Server**: **Responds to kubectl**, admins, DevOps, and third-party clients, manages resources and cluster state.
2. **etcd**: **Responds to API server**, stores cluster configuration, state, and secrets (only the API server interacts with etcd).
3. **Kubelet**: **Responds to API server** for pod status, logs, and exec commands.

> The roles mentioned above for clients and servers are **indicative**, not exhaustive. Kubernetes components may interact in multiple ways, and their responsibilities can evolve as the system grows and new features are added.

**Client or Server? It Depends on the Context**

In Kubernetes, whether a component acts as a **client** or **server** depends entirely on the direction of the request.

A single component can play both roles depending on the scenario. For example, when a user or a tool like `kubectl` accesses the **API server**, the API server acts as the **server**. However, when the **API server** communicates with another component like the **kubelet**—for fetching logs (`kubectl logs`), executing (`kubectl exec`) into containers, or retrieving node and pod status—the API server becomes the **client**, and the kubelet acts as the **server**.

Components such as the **scheduler**, **controller manager**, and **kube-proxy** are always **clients** because they initiate communication with the **API server** to get the desired cluster state, pod placements, or service endpoints.

On the other hand, **etcd** is **always a server** in the Kubernetes architecture. It **only** communicates with the **API server**, which acts as its **client** — no other component talks to etcd directly. This design keeps etcd isolated and secure, as it holds the cluster’s source of truth.

> **Note:** In **HA etcd setups**, each etcd node also acts as a **client** when talking to its **peer members** for cluster replication and consensus.
> However, this internal etcd-to-etcd communication is **independent of the Kubernetes control plane**.

---

## Understanding TLS in Kubernetes: No More Memorizing File Paths

TLS and certificates are core to how Kubernetes secures communication between its components — but let’s be honest, most explanations out there reduce it to a bunch of file paths and flags you’re expected to memorize.

We’re going to take a different approach.

Instead of rote learning, you'll learn how to **investigate and reason through** TLS communications in Kubernetes by **reading and interpreting configuration files**. This way, no matter the cluster setup — whether it’s a managed cloud offering or a custom on-prem deployment — you’ll know exactly where to look and how to figure things out.

**What You’ll Learn from the Next 3 Examples**

We’ll walk through **three real-world scenarios** of **mutual TLS (mTLS)** between core Kubernetes components. In each one, you’ll learn how to:

* **Identify who is the client and who is the server**
* **Determine which certificate is presented by each party**
* **Understand which CA signs those certificates and how trust is established**
* **Trace certificate locations and verify them using OpenSSL**
* **Inspect kubeconfig files to understand client behavior**

> **Key Idea:** You do **not** need to memorize certificate paths.
> You just need to know **where to look** — and that’s always the component’s configuration file.


**Why These Examples?**

These are not hand-picked just for simplicity. The interactions between:

1. **Scheduler and API Server**
2. **API Server and etcd**
3. **API Server and Kubelet**

…cover the **most critical and foundational TLS flows** in Kubernetes. If you understand these, you can apply the same logic to almost any other TLS interaction in the cluster — including kubelet as a client, webhooks, and even ingress traffic.

---

## Example 1: mTLS Between Scheduler (Client) and API Server (Server)

![Alt text](/images/33c.png)

Let’s walk through an end-to-end explanation of how **mutual TLS (mTLS)** works in Kubernetes — specifically, the communication between the **kube-scheduler** (client) and the **kube-apiserver** (server).

This example will show you **how to figure out certificate paths and their roles** by inspecting configuration files — **not by memorizing paths**.

---

### Key Principle: All Clients Use a Kubeconfig File to Connect to the API Server

> **IMPORTANT:** Anything that connects to the API server — whether it's `kubectl`, a control plane component like the scheduler or controller-manager, or an automation tool — uses a **kubeconfig file** to do so.

We already saw this in action in a previous lecture when **Seema**, using `kubectl`, connected to the API server using her personal `~/.kube/config` file. The same logic applies here: the **scheduler is also a client**, and its communication with the API server is facilitated by a kubeconfig file — in this case, `/etc/kubernetes/scheduler.conf`.

> 🔍 For `kube-proxy`, since it runs as a **DaemonSet**, its kubeconfig file is mounted into each pod. You can `kubectl exec` into a `kube-proxy` pod and find the kubeconfig typically at:
> `/var/lib/kube-proxy/kubeconfig`

This principle not only helps you understand **how TLS authentication is wired** in Kubernetes, but also gives you a **consistent mental model** for troubleshooting and inspecting certificates.

---

## Key TLS and Configuration File Locations (Control Plane & Nodes)

| Purpose                                  | Typical Path                                            | Notes                                                                  |
| ---------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------- |
| Kubeconfig files                         | `/etc/kubernetes/*.conf`                                | Used by core components (e.g., controller-manager, scheduler, kubelet) |
| Static Pod manifests                     | `/etc/kubernetes/manifests`                             | Includes API server, controller-manager, etcd,  scheduler                     |
| API server & control plane certs         | `/etc/kubernetes/pki`                                   | Certificates and keys for API server                                   |
| etcd certificates                        | `/etc/kubernetes/pki/etcd`                              | Only present if etcd is running locally                                |
| Kubelet certificates (on **all nodes**)  | `/var/lib/kubelet/pki`                                  | Includes kubelet server & client certs                                 |
| kube-proxy configuration (DaemonSet pod) | Inside `/var/lib/kube-proxy/` or mounted into container | Use `kubectl exec` into the kube-proxy pod to inspect                  |

---

## SERVER-SIDE: How the API Server Presents Its Certificate

**Goal:** Understand what certificate the API server presents and how the scheduler verifies it.

---

### Step 1: Who’s the Server?

In this interaction:

* **Scheduler** → acts as the **client**
* **API Server** → acts as the **server**

---

### Step 2: How Does the Server Present a Certificate?

Since API server is a static pod, inspect its manifest:

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Look for this flag:

```yaml
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
```

This tells us the API server presents this certificate:

```bash
/etc/kubernetes/pki/apiserver.crt
```

To view its contents:

```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
```

You’ll see output like:

```bash
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 8665438048378157642 (0x7841d1fe58bbfa4a)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 17 19:09:09 2026 GMT
        Subject: CN = kube-apiserver
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d4:e0:ec:4a:92:47:fa:47:36:70:d6:fd:1c:d4:
                    93:b3:5e:66:d3:43:53:bc:7a:4d:38:45:6d:aa:b6:
                    66:95:1d:0f:be:3b:48:a0:dd:22:5f:94:72:4c:2f:
                    d4:db:50:2e:58:af:5b:64:8e:58:f7:02:f3:4c:9a:
                    d8:12:03:51:a1:8d:82:3f:71:c2:c2:dd:66:7c:bc:
                    ec:77:fe:31:26:d8:40:f0:08:75:de:fb:87:e7:25:
                    74:ae:07:e4:58:77:da:e1:64:07:91:ce:85:1b:a7:
                    8f:c2:6f:47:08:08:e3:30:76:23:42:0e:53:47:d6:
                    26:da:22:ea:d6:1a:60:5e:dd:77:b8:ab:10:d3:ac:
                    ad:c2:07:ff:4e:8a:c0:f6:5a:5e:12:92:bb:a8:d7:
                    0a:a5:a3:05:3f:40:7e:2c:a6:4a:f6:72:7b:89:ff:
                    da:54:f8:29:eb:9d:20:93:45:a4:42:18:a8:51:21:
                    00:64:87:ae:f9:08:0b:be:d1:1f:5f:a0:b8:d8:c9:
                    dd:5e:71:ce:36:2e:2a:e2:3b:29:52:e7:4d:17:bf:
                    ec:42:9c:08:3e:78:93:21:40:96:7d:e2:07:be:a9:
                    f6:94:55:11:0d:4b:8a:fc:af:50:43:3f:2e:72:a6:
                    58:97:25:b7:08:6e:3b:08:97:2d:4b:63:b6:8c:f1:
                    ef:35
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
            X509v3 Subject Alternative Name: 
                DNS:controlplane, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP Address:10.96.0.1, IP Address:172.30.1.2
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        58:a5:61:75:b4:fb:23:94:c8:3f:19:fa:53:11:2c:a5:ad:7c:
        30:be:34:0c:fd:b8:c5:86:e5:6f:84:6a:42:67:b9:2b:13:4e:
        69:ae:62:1f:c4:9e:15:68:b5:2a:2a:83:59:5a:09:85:f5:e7:
        eb:cf:5e:0f:cd:2e:7d:21:2e:c3:8a:af:55:8e:75:04:de:27:
        dc:ea:fb:61:79:2c:2b:10:a8:4e:f5:76:6c:ca:fd:12:3f:72:
        71:38:45:9e:e2:17:36:ca:df:00:61:25:64:0d:b3:0a:f7:fa:
        01:e8:4c:a8:69:79:0d:e8:b3:4d:5f:07:f3:50:d9:00:3c:31:
        f7:89:12:8a:6f:d7:f6:ac:ba:57:72:7f:95:f7:48:2f:56:24:
        c3:7d:14:f9:fc:ac:f8:00:ea:08:43:af:f5:84:f9:8e:4c:4f:
        48:06:55:91:dc:ab:8b:3b:03:be:c1:77:05:f2:75:e3:64:6d:
        32:4b:12:9d:d1:7f:3b:7f:f5:fa:6c:f9:4f:91:9e:9a:f5:74:
        b1:a2:6e:4e:e6:d1:85:f6:46:04:91:f5:01:23:72:f4:62:47:
        40:5f:d7:19:86:7b:db:fe:34:05:32:62:68:f1:9c:e4:01:dc:
        13:95:42:55:fc:46:9e:7a:65:a6:7f:a8:d0:fd:5b:c2:64:e0:
        95:d0:af:ee
```

This confirms:

* The API server identifies itself as `kube-apiserver`
* The certificate is signed by the **Kubernetes cluster CA**

- Online SSL certificate decoder
https://www.sslshopper.com/certificate-decoder.html
---

### Step 3: How Does the Scheduler Trust the API Server’s Certificate?

To verify the server's certificate, the **scheduler must trust the CA** that signed it.

Here's how that works:

#### a. Locate the Kubeconfig File

Every component/client want to communicate with the api-server must have kubeconfig file(server+ca.crt).
The scheduler uses a kubeconfig to connect to the API server. Find it by checking:

```bash
cat /etc/kubernetes/manifests/kube-scheduler.yaml
```
Look for:
```yaml
--kubeconfig=/etc/kubernetes/scheduler.conf
```
```bash
apiVersion: v1
kind: Pod
metadata:
  labels:
    component: kube-scheduler
    tier: control-plane
  name: kube-scheduler
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-scheduler
    - --authentication-kubeconfig=/etc/kubernetes/scheduler.conf
    - --authorization-kubeconfig=/etc/kubernetes/scheduler.conf
    - --bind-address=127.0.0.1
    - --kubeconfig=/etc/kubernetes/scheduler.conf
    - --leader-elect=true
    image: registry.k8s.io/kube-scheduler:v1.34.1
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 8
      httpGet:
        host: 127.0.0.1
        path: /livez
        port: probe-port
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    name: kube-scheduler
    ports:
    - containerPort: 10259
      name: probe-port
      protocol: TCP
    readinessProbe:
      failureThreshold: 3
      httpGet:
        host: 127.0.0.1
        path: /readyz
        port: probe-port
        scheme: HTTPS
      periodSeconds: 1
      timeoutSeconds: 15
    resources:
      requests:
        cpu: 25m
    startupProbe:
      failureThreshold: 24
      httpGet:
        host: 127.0.0.1
        path: /livez
        port: probe-port
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/kubernetes/scheduler.conf
      name: kubeconfig
      readOnly: true
  hostNetwork: true
  priority: 2000001000
  priorityClassName: system-node-critical
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - hostPath:
      path: /etc/kubernetes/scheduler.conf
      type: FileOrCreate
    name: kubeconfig
status: {}
```

#### b. Inspect the CA Data

Open the kubeconfig file:

```bash
cat /etc/kubernetes/scheduler.conf
```
Look for:
```yaml
certificate-authority-data: <base64 encoded cert> #it is the crt(public key) verify thatt the crt for the api-server is sign by the CA(private key)
```
This is the **CA certificate** (in base64) used to validate the API server’s cert.

```bash
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJUytlNHFCRmpjeEl3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TlRFeE1UY3hPVEEwTURsYUZ3MHpOVEV4TVRVeE9UQTVNRGxhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUURYbVpLaHBkTkRTRTVaT1JRU05wWTk4M01MZFJWWUROWERxWGlnME0rUDM1a2hObWJ6Qm1PeXpwM2QKVG1pWVRTNzBvK2tLRjlKWjZrQk9NbFVsdHljMVJVU094SmZ6MExvZENwRWlSc1BIbDUxaUp1aExZREFhSTBxeApxck1hcEVmUEYxc3ZhTHQycGh1bW9OdVV6MlQxUW90aks3akpBR0dSMVVoLzAzVEd4UnJLYVhha2xOUVpQTk1lCm1mS3dOa2NYbWNCRWY0YTNxWDY4M29RVHJTbTdJMGtQWGt4UHpmVXlyNkdrVjJKejdCWlNkRXhrUHd5Q29RM2UKSVZnVnd6em5DbVVjeTJOTXJnL3FoL3ZBM1ZvbENra3B4UkZzNVpDYmRFckJ2R28vV2RVeEQyWVBTdFRWZ2JJbQozdTJoVjVRcmp6bG9zOGErOFNKd1MxaUUwejg5QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTTnRvVkpad3J1SHMvbHZ5Q1dwckNaeVJZOHp6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1hWM2Z4c2RHUwp3WXhQc3JkZzhPSnlUWGxiWlhyVEVsWndsWTJ5ZHVXQ0ZuY2o1dWhwRGpZWXJ0c1k0dDZBNUtZMmdERFFYRldpCncvbXp0Q2xSa1BReENVYnZFUXJQem9Db1lpTjV4S29PeFRxVU5qT004cmNZNk1HN1VYRVQ4bm1NV1lCRzQ2RXQKc1d1anEva3ZQU0ljSmpZNWVzdHppRXdlVjA3Vzc3N0hIY25aMlhVNHg0SVQzcmlYSmtZbHBIM1V1ZUpmalo4LwpoWFdCZnpiVEMyLzNCRDBZTy9BV1dacTN3M2l0dmF4dDFrTWhnS2wzWkpxZUkyZkIzcnEyZkljTmJRMHRBb2VoCkRkQ2Qza2VYOC9Md2RJZCsyWjR6U3JRQVBUN2FrQUo1ckFnTEpTS1VlSGtKMzNicERQb1FGVmFiSTZVVmZtYVkKaGI1M0ljOFB1NFNQCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://172.30.1.2:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-scheduler
  name: system:kube-scheduler@kubernetes
current-context: system:kube-scheduler@kubernetes
kind: Config
users:
- name: system:kube-scheduler
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUREVENDQWZXZ0F3SUJBZ0lJU3VTS0NLd3BjNjR3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TlRFeE1UY3hPVEEwTURsYUZ3MHlOakV4TVRjeE9UQTVNRGxhTUNBeApIakFjQmdOVkJBTVRGWE41YzNSbGJUcHJkV0psTFhOamFHVmtkV3hsY2pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCCkJRQURnZ0VQQURDQ0FRb0NnZ0VCQU5GYXVMWGJNK1c5MGUydVBsbnAwbVM3cWltcFVIcHNKL1pVclBwaWRTc3UKa2tka0ZuanNMbDZxNE9hTXdrNTAxeEJYR2ZIMDhUdTYzNmpMejA0d0QrQmF4SExBQytXbWhQMnd1M2lzN0VwYQpxY3hnWVlpYkxCM0xMaDh3OUV3N3hPdTRONHNtSElqRDF2aWVZV3NnMUFlMTJBVGs5TWhzNG5ON2NGR2ZaMVEwCldzZjU5bjNWOHRocGN4ZWFVV3orOVBnK2EwT0pleGJWTTlWU1RxcWVGRC83WTdFczcyN25UbzQ5RGdQWldzZFYKajBaWTBoN242eW9lcUJ0bVdOSng1bkV6WnNqQVU2NXBIZTdIbER1QVpnOGUrMnJEcTRWVDJNajNBM2hsSHAwTwpzc1VlbVdBMk50aWJEbXlHazExZUlkRTVWWC9sK2hhWWFxbERvSmZPLzhNQ0F3RUFBYU5XTUZRd0RnWURWUjBQCkFRSC9CQVFEQWdXZ01CTUdBMVVkSlFRTU1Bb0dDQ3NHQVFVRkJ3TUNNQXdHQTFVZEV3RUIvd1FDTUFBd0h3WUQKVlIwakJCZ3dGb0FVamJhRlNXY0s3aDdQNWI4Z2xxYXdtY2tXUE04d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQgpBR2loVlRsTk5jazl5OUVDN2htRjJyL0R4RUYwV2M5RjFMQ1R1Zk9qdkFKNkpvMXVQRlZWZjNDZGtFNnd6KzRNCkFROUpFV3RFbHVtNmZNeFpTRE5LOWtTbUowZGpPbEd5VGlDcFZmN25PS25YaWhYZ1VHbnU3M0RTZ2plZlJ2RTkKTENVbFpBYmJld2RuYkVlM050VnFzSUx3Y3BSUmtvcUZ3TGxCQmdQcXpDcHJZQ2VBS1hIS1F3SXJjNEZVR2hNbwpoSkQ1YXlObUVCM29ORGhnckpDL1phdmtBZndrTFBWeE9wRmlnUG9sVVFoNXhETFM5WWowb3VWZGJYbU00OFRpCjBGUDZJdEVBb1VoOVFPc01yajQrSzFFWmdVWFQyRldSeEY3czA0ZGoyOG1HVi80TXRZMDBHSTk3dUdYVC9YbVEKRDZnZzhDeVA5SHVLTFJHakVMTHJCTDg9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcEFJQkFBS0NBUUVBMFZxNHRkc3o1YjNSN2E0K1dlblNaTHVxS2FsUWVtd245bFNzK21KMUt5NlNSMlFXCmVPd3VYcXJnNW96Q1RuVFhFRmNaOGZUeE83cmZxTXZQVGpBUDRGckVjc0FMNWFhRS9iQzdlS3pzU2xxcHpHQmgKaUpzc0hjc3VIekQwVER2RTY3ZzNpeVljaU1QVytKNWhheURVQjdYWUJPVDB5R3ppYzN0d1VaOW5WRFJheC9uMgpmZFh5MkdsekY1cFJiUDcwK0Q1clE0bDdGdFV6MVZKT3FwNFVQL3Rqc1N6dmJ1ZE9qajBPQTlsYXgxV1BSbGpTCkh1ZnJLaDZvRzJaWTBuSG1jVE5teU1CVHJta2Q3c2VVTzRCbUR4Nzdhc09yaFZQWXlQY0RlR1VlblE2eXhSNloKWURZMjJKc09iSWFUWFY0aDBUbFZmK1g2RnBocXFVT2dsODcvd3dJREFRQUJBb0lCQUdEdEJiTjhoeXlJazViZApJeFR4d216TXpkMTMvRUNScm5iSGdVWnpLeGdRK2J4L3hEKzc2VVAvRFJ6d2NrMXNudDE3MWhGRmZDSlJSSmViCnRLRFljNkZGcE1vVHkrNUpDQzJFRTJldGQ4Qjg5VHdnSzBmWnY3VVRpb2o2VzBDb00yV0c1b0JQNXNvVEVZWU4KbmNEQmRDa1ZzYXVpYlFvV0QwbTBEcTViaExWZ3FWYnVGOTNFZ3lMS1hPSjcrY0JuWDhLM2VlMEpQbHZobE01MwpNZXVMczZweHAydXVkdmJWU3J1bjJOSDJ1MXhZcm5xc3puRk83TElvdjJJNVJ0anlkQVpjcU82T0cyZzlvTjFPClpuYngzKzAyelNybWk1Z2NMZmpSM1ZYUXFmNjVRUFJSZkdYc1RxYXRrTFk2UUg3RDI1NWpYTGhjMnNkWW42M3QKaGZGVWJxRUNnWUVBOE12SUczQ1NnZkF4Y2ZleWtnVFg1TDN1UDFUZFpqV0pnbEtMc3B0RFFHSk9SK2VheWtSdApaN0gycXZHUWVIaG9PZ0o4eGlkR3lhaUkwMVNYZW90a2xWeUh6MTBYUE9LOHFqdkVKcVFBcUZ0Nm1FSTJnQVgxCmhVVHlqSnowZW43TkJ6Yzk5Ykt5Q0pYOTA2RU1FWGRTY2lPVTBjdS9qNnlpbmFrWmU0QjRRSmtDZ1lFQTNwSzMKNGFydkJ6WmVMVUs1LzkwTVdaaXlrNzBhUGZuekZLV2ZDVDlRa3g0MWtuaE9JdVRSSVBOZStBWEFPWW9TTnB3aQprbWRrcTVSV1dwazFTVWFOTzRyUmYwTmZidHdSRkxrTE1UUkdkbGtXcUNqeEpWM2JwcVdkbEpOV0RIMnJqeC9uCmFyTENIeFQzcGJaUFh1QTRsZVJzMm9xS3FBRGZQNEZHMEw4SVVMc0NnWUVBaFhud2FvVjBNT0xjQmJpd0c1RGoKdThBc21KNktPMlhoMjRPMlBFTWtmRVFCOEluSm0rVmlYK0NlUXhPMGFaTVU4MUw5cHptT1c2bzRiaXl0NnhmcApvWUd4SnBrTGtJeCsyRDVZOUxKa1N1NnFma3YxdWZHVHIxUVF2ekVocytVbDhhSUZqblNIaTRyWk1MNU0ya0d5ClNlSy9VNndGZTdiT1RXYTI0V2JOUWNFQ2dZRUEydnJoSFk4T3N6cmpkNFpoOTRHbEovV2JKTTMxcHFwblpaWDUKbmFDRWh1bys3UWVlWUtoZHRSeWRBRXF3TUN4TzlSbXl6ZllaenRJWUQvVVN2ekJCdmlZN0xnbThPQmNlV3hRZwpGZDRId1dLdmJ1MHhMSUZtblZQdWNRSndzOE5rNm1FS1R5am00cXUvWjNPeUxYZFBWUEl6d3VSeHZROTJsa1Y3CnhkOWRzQWNDZ1lCS3d2aS9XYTlKdzgrNFdsRjY5eHF4UTFXNUZKU1I0bnNCZ1pyT2wxa1ZWY3JYM1ljWW81SFMKanhnSUJGaEtMZXVURXd6M3ZUVE5xMENKR0RQRWJrekVuYUdjbmJHVnh4azh4SmJOQ0IrZ01seVVZSkVJZldMbApUVlk2MUFua1pEcE1aOCs0b1JsMFgvTnVrbnhyL1Z1ZEFybnMwdm5wOVp3cy9na3AvT21jcGc9PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
```

You can decode and inspect it:

```bash
echo -n "<base64 data>" | base64 --decode > ca.crt

echo -n LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJUytlNHFCRmpjeEl3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TlRFeE1UY3hPVEEwTURsYUZ3MHpOVEV4TVRVeE9UQTVNRGxhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUURYbVpLaHBkTkRTRTVaT1JRU05wWTk4M01MZFJWWUROWERxWGlnME0rUDM1a2hObWJ6Qm1PeXpwM2QKVG1pWVRTNzBvK2tLRjlKWjZrQk9NbFVsdHljMVJVU094SmZ6MExvZENwRWlSc1BIbDUxaUp1aExZREFhSTBxeApxck1hcEVmUEYxc3ZhTHQycGh1bW9OdVV6MlQxUW90aks3akpBR0dSMVVoLzAzVEd4UnJLYVhha2xOUVpQTk1lCm1mS3dOa2NYbWNCRWY0YTNxWDY4M29RVHJTbTdJMGtQWGt4UHpmVXlyNkdrVjJKejdCWlNkRXhrUHd5Q29RM2UKSVZnVnd6em5DbVVjeTJOTXJnL3FoL3ZBM1ZvbENra3B4UkZzNVpDYmRFckJ2R28vV2RVeEQyWVBTdFRWZ2JJbQozdTJoVjVRcmp6bG9zOGErOFNKd1MxaUUwejg5QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTTnRvVkpad3J1SHMvbHZ5Q1dwckNaeVJZOHp6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1hWM2Z4c2RHUwp3WXhQc3JkZzhPSnlUWGxiWlhyVEVsWndsWTJ5ZHVXQ0ZuY2o1dWhwRGpZWXJ0c1k0dDZBNUtZMmdERFFYRldpCncvbXp0Q2xSa1BReENVYnZFUXJQem9Db1lpTjV4S29PeFRxVU5qT004cmNZNk1HN1VYRVQ4bm1NV1lCRzQ2RXQKc1d1anEva3ZQU0ljSmpZNWVzdHppRXdlVjA3Vzc3N0hIY25aMlhVNHg0SVQzcmlYSmtZbHBIM1V1ZUpmalo4LwpoWFdCZnpiVEMyLzNCRDBZTy9BV1dacTN3M2l0dmF4dDFrTWhnS2wzWkpxZUkyZkIzcnEyZkljTmJRMHRBb2VoCkRkQ2Qza2VYOC9Md2RJZCsyWjR6U3JRQVBUN2FrQUo1ckFnTEpTS1VlSGtKMzNicERQb1FGVmFiSTZVVmZtYVkKaGI1M0ljOFB1NFNQCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K | base64 -d > ca.crt
```
```bash
cat ca.crt
-----BEGIN CERTIFICATE-----
MIIDBTCCAe2gAwIBAgIIS+e4qBFjcxIwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yNTExMTcxOTA0MDlaFw0zNTExMTUxOTA5MDlaMBUx
EzARBgNVBAMTCmt1YmVybmV0ZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQDXmZKhpdNDSE5ZORQSNpY983MLdRVYDNXDqXig0M+P35khNmbzBmOyzp3d
TmiYTS70o+kKF9JZ6kBOMlUltyc1RUSOxJfz0LodCpEiRsPHl51iJuhLYDAaI0qx
qrMapEfPF1svaLt2phumoNuUz2T1QotjK7jJAGGR1Uh/03TGxRrKaXaklNQZPNMe
mfKwNkcXmcBEf4a3qX683oQTrSm7I0kPXkxPzfUyr6GkV2Jz7BZSdExkPwyCoQ3e
IVgVwzznCmUcy2NMrg/qh/vA3VolCkkpxRFs5ZCbdErBvGo/WdUxD2YPStTVgbIm
3u2hV5Qrjzlos8a+8SJwS1iE0z89AgMBAAGjWTBXMA4GA1UdDwEB/wQEAwICpDAP
BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSNtoVJZwruHs/lvyCWprCZyRY8zzAV
BgNVHREEDjAMggprdWJlcm5ldGVzMA0GCSqGSIb3DQEBCwUAA4IBAQCXV3fxsdGS
wYxPsrdg8OJyTXlbZXrTElZwlY2yduWCFncj5uhpDjYYrtsY4t6A5KY2gDDQXFWi
w/mztClRkPQxCUbvEQrPzoCoYiN5xKoOxTqUNjOM8rcY6MG7UXET8nmMWYBG46Et
sWujq/kvPSIcJjY5estziEweV07W777HHcnZ2XU4x4IT3riXJkYlpH3UueJfjZ8/
hXWBfzbTC2/3BD0YO/AWWZq3w3itvaxt1kMhgKl3ZJqeI2fB3rq2fIcNbQ0tAoeh
DdCd3keX8/LwdId+2Z4zSrQAPT7akAJ5rAgLJSKUeHkJ33bpDPoQFVabI6UVfmaY
hb53Ic8Pu4SP
-----END CERTIFICATE-----
```
```bash
openssl x509 -in ca.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 5469543304450503442 (0x4be7b8a811637312)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 15 19:09:09 2035 GMT
        Subject: CN = kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d7:99:92:a1:a5:d3:43:48:4e:59:39:14:12:36:
                    96:3d:f3:73:0b:75:15:58:0c:d5:c3:a9:78:a0:d0:
                    cf:8f:df:99:21:36:66:f3:06:63:b2:ce:9d:dd:4e:
                    68:98:4d:2e:f4:a3:e9:0a:17:d2:59:ea:40:4e:32:
                    55:25:b7:27:35:45:44:8e:c4:97:f3:d0:ba:1d:0a:
                    91:22:46:c3:c7:97:9d:62:26:e8:4b:60:30:1a:23:
                    4a:b1:aa:b3:1a:a4:47:cf:17:5b:2f:68:bb:76:a6:
                    1b:a6:a0:db:94:cf:64:f5:42:8b:63:2b:b8:c9:00:
                    61:91:d5:48:7f:d3:74:c6:c5:1a:ca:69:76:a4:94:
                    d4:19:3c:d3:1e:99:f2:b0:36:47:17:99:c0:44:7f:
                    86:b7:a9:7e:bc:de:84:13:ad:29:bb:23:49:0f:5e:
                    4c:4f:cd:f5:32:af:a1:a4:57:62:73:ec:16:52:74:
                    4c:64:3f:0c:82:a1:0d:de:21:58:15:c3:3c:e7:0a:
                    65:1c:cb:63:4c:ae:0f:ea:87:fb:c0:dd:5a:25:0a:
                    49:29:c5:11:6c:e5:90:9b:74:4a:c1:bc:6a:3f:59:
                    d5:31:0f:66:0f:4a:d4:d5:81:b2:26:de:ed:a1:57:
                    94:2b:8f:39:68:b3:c6:be:f1:22:70:4b:58:84:d3:
                    3f:3d
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
            X509v3 Subject Alternative Name: 
                DNS:kubernetes
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        97:57:77:f1:b1:d1:92:c1:8c:4f:b2:b7:60:f0:e2:72:4d:79:
        5b:65:7a:d3:12:56:70:95:8d:b2:76:e5:82:16:77:23:e6:e8:
        69:0e:36:18:ae:db:18:e2:de:80:e4:a6:36:80:30:d0:5c:55:
        a2:c3:f9:b3:b4:29:51:90:f4:31:09:46:ef:11:0a:cf:ce:80:
        a8:62:23:79:c4:aa:0e:c5:3a:94:36:33:8c:f2:b7:18:e8:c1:
        bb:51:71:13:f2:79:8c:59:80:46:e3:a1:2d:b1:6b:a3:ab:f9:
        2f:3d:22:1c:26:36:39:7a:cb:73:88:4c:1e:57:4e:d6:ef:be:
        c7:1d:c9:d9:d9:75:38:c7:82:13:de:b8:97:26:46:25:a4:7d:
        d4:b9:e2:5f:8d:9f:3f:85:75:81:7f:36:d3:0b:6f:f7:04:3d:
        18:3b:f0:16:59:9a:b7:c3:78:ad:bd:ac:6d:d6:43:21:80:a9:
        77:64:9a:9e:23:67:c1:de:ba:b6:7c:87:0d:6d:0d:2d:02:87:
        a1:0d:d0:9d:de:47:97:f3:f2:f0:74:87:7e:d9:9e:33:4a:b4:
        00:3d:3e:da:90:02:79:ac:08:0b:25:22:94:78:79:09:df:76:
        e9:0c:fa:10:15:56:9b:23:a5:15:7e:66:98:85:be:77:21:cf:
        0f:bb:84:8f
```

This certificate will show:

```
Subject: CN=kubernetes
Issuer: CN=kubernetes
```
Root certificates always have Subject CN and Issuer CN same.

That means:

* It’s a **self-signed cluster root CA**
* The **scheduler trusts this CA**
* So it can **verify the identity of the API server**

---

**Why Do Popular Certificate Authorities Also Have a Root CA?**
  Many well-known Certificate Authorities (CAs), like **Sectigo**, **Let's Encrypt**, or **DigiCert**, operate their own **Root Certificate Authority (Root CA)** in addition to one or more **Intermediate CAs**.

  **What Is a Root CA and Why Does It Exist?**
  * A **Root CA** sits at the **top of the trust hierarchy** — it is the anchor of the entire Public Key Infrastructure (PKI).
  * A **root certificate is always self-signed** because there is no higher authority to sign it. That’s why you might sometimes see warnings like “this certificate is self-signed.”
  * However, **self-signed is acceptable** when the certificate belongs to a **trusted root**, which is explicitly trusted by operating systems, browsers, and other clients.

  **Why Have a Separate Root and Intermediate CA?**
  * **Security:** The root CA’s private key is kept **offline or in secure environments**. Intermediate CAs handle day-to-day certificate issuance, minimizing exposure.
  * **Resilience:** If an **intermediate CA is compromised**, it can be revoked without affecting the root. This limits the blast radius.
  * **Best Practice:** This layered structure follows industry standards for security and trust management.

```bash
📌 PUBLIC KEY INFRASTRUCTURE (PKI): ROOT CA vs INTERMEDIATE CA

1. Why use multiple CAs?
   - The Root CA is the most powerful authority in PKI.
   - If the Root CA key is leaked → the entire trust system collapses.
   - To avoid that, the Root CA stays offline/air-gapped and is used only to sign Intermediate CAs.
   - All day-to-day certificate signing (servers, clients, kubelets, etc.) is done by Intermediate CAs.
   - This reduces risk because only the Intermediate CA is exposed, not the Root.

2. How the Root CA protects the Intermediate CA?
   - The Root CA is "offline" and not used in any network operations.
   - It signs Intermediate CA certificates and then is stored securely (HSM, cold storage).
   - If an Intermediate CA is compromised, the Root CA can revoke that Intermediate CA.
   - This “chain of trust” prevents compromise from spreading to the whole PKI.

3. What happens if the Intermediate CA is leaked?
   - An attacker can issue valid certificates for anything under that CA (servers, clients).
   - But the damage is LIMITED to that intermediate CA only.
   - You can revoke the Intermediate CA certificate from the Root CA.
   - Clients will stop trusting certificates issued by the compromised intermediate.
   - The Root CA, and other intermediates, remain safe.

4. What happens if the Root CA is leaked?
   - The attacker can create new intermediates and new server/client certificates.
   - No revocation method can fully stop this.
   - Entire PKI must be rebuilt from scratch.
   - This is why Root CAs are kept offline and protected with maximum security.

5. Practical Kubernetes Example:
   - etcd can have its own CA because compromise of etcd CA should NOT compromise the API server.
   - The Kubernetes API server, controller-manager, and scheduler often share a cluster CA.
   - If the etcd CA is compromised, the attacker can impersonate etcd only, not the API server.
   - If the API server CA is compromised, attacker can impersonate API, but NOT the Root CA.
   - Using multiple CAs limits blast radius in case one CA is leaked.

Summary:
   - Root CA = most trusted, kept offline, signs intermediates only.
   - Intermediate CA = daily-use CA, can be revoked if compromised.
   - Multiple CAs = compartmentalized trust → compromise of one CA does NOT destroy the whole system.
```
```bash
────────────────────────────────────────────────────────────────────────────
                   🔐 HOW ROOT CA PROTECTS INTERMEDIATE CA 
             AND HOW TO REVOKE A COMPROMISED INTERMEDIATE CA

1) WHY INTERMEDIATE CAs EXIST
• The Root CA is the most powerful key in the PKI.
• It must be offline, locked in HSMs, rarely used.
• Intermediate CAs issue end-entity certificates (API server, kubelets, etc.).
• If an Intermediate CA is compromised, Root CA stays safe because:
    - The attacker cannot sign new intermediates.
    - The attacker cannot impersonate the Root.
    - The attacker cannot sign certs that chain directly to the Root.

2) WHAT IF THE INTERMEDIATE CA PRIVATE KEY IS LEAKED?
• An attacker can issue VALID certificates for ANY service under that CA.
• These certificates will still chain to the Root unless revoked.
• This is why we NEVER use Root CA directly.
• The blast radius stays limited to certificates signed by that one Intermediate.

3) HOW THE ROOT CA PROTECTS ITSELF
• The Root CA does NOT need to be online.
• Its private key is stored offline → cannot be stolen remotely.
• Only the Intermediate CA is online, so only its key is exposed to attack.
• Certificate chains keep responsibilities separated:
    Root CA → Intermediate CA → Server/Client certs

4) IF INTERMEDIATE CA IS COMPROMISED → WHAT TO DO?
You must **revoke the Intermediate CA certificate** using the Root CA.

Essentially:
(1) Generate a CRL that marks the Intermediate CA cert as revoked
(2) Distribute the CRL to all systems
(3) Rotate a new Intermediate CA

5) HOW TO REVOKE INTERMEDIATE CA CERTIFICATE (OpenSSL example)

Step A — Mark the Intermediate CA certificate as revoked
   # On the Root CA system (offline system)
   openssl ca \
      -config root-ca.conf \
      -revoke intermediate-ca.crt

Step B — Regenerate the CRL from the Root CA
   openssl ca \
      -config root-ca.conf \
      -gencrl \
      -out root-ca.crl

Step C — Publish the CRL
   • Put root-ca.crl in your CRL distribution point (CDP)
   • Update HTTPS/LDAP server that hosts CRL
   • Update OCSP responder (optional)

Step D — Replace the Intermediate CA
   • Generate NEW Intermediate CA key + CSR
   • Sign it again using the Root CA
   • Re-issue new server/client certificates under the new Intermediate CA

6) WHAT HAPPENS NEXT?
• All systems validating certificates will check CRL/OCSP
• They will see that the OLD Intermediate CA is revoked
• Any certificate issued by that compromised Intermediate CA becomes invalid
• Trust is restored using the NEW intermediate CA

7) SUMMARY
• Intermediate CA compromise = bad, but contained
• Root CA stays safe because it is offline
• Revocation at the Root CA instantly kills the entire Intermediate CA
• A new Intermediate CA must be created afterwards
────────────────────────────────────────────────────────────────────────────
```
---

  **TLS Certificate Chain Flow (Using pinkbank.com as Example)**

  **Scenario:**

  Seema visits `pinkbank.com`, which uses a TLS certificate from Let’s Encrypt.

  **What Happens:**

  1. **pinkbank.com** presents:

      * Its **own certificate** (called the **leaf certificate**)
        e.g., `CN=pinkbank.com`
      * Its intermediate certificate, issued by Let’s Encrypt Root CA (e.g., ISRG Root X2) to Let’s Encrypt Intermediate CA (e.g., CN=R3 or CN=E1, depending on the chain used).

  2. The browser then:

      * **Verifies the signature on the leaf cert** using the **public key of the intermediate CA**.
      * **Verifies the intermediate CA’s certificate** using the **public key of the root CA**, which is already **preinstalled and trusted** in the browser’s trust store.

  3. The **Root CA** (e.g., `ISRG Root X2`) is:

      * **Not sent** by the server.
      * **Already trusted** by Seema's browser (this is why root CAs are preloaded in browser/OS trust stores).

  **The flow is:**

  ```
  pinkbank.com (leaf cert) 
    ⬅ signed by 
  Let's Encrypt Intermediate CA (R3/E1)
    ⬅ signed by 
  ISRG Root X2 (Root CA, already in browser)
  ```

  > When Seema's browser sees this chain, it uses the **root CA it already trusts** to verify the chain of trust. That’s why even though `pinkbank.com` doesn’t send the root cert, the validation still succeeds.

![](/images/image-root-ca.png)

---


# **Full Detailed Certificate Validation Process (Browser Side)**

*(When Seema opens `https://pinkbank.com`)*

Let’s go VERY deep — at the level of signatures, certificate fields, trust store, and cryptographic validation.

---

# **STEP 1 — Server Sends Certificates to Browser**

When Seema visits:

```
https://pinkbank.com
```

The server sends **two certificates**:

### 1️⃣ Leaf Certificate (also called server certificate)

```
Subject: CN=pinkbank.com
Issued by: Let's Encrypt R3 (Intermediate CA)
Contains: Server Public Key
```

### 2️⃣ Intermediate CA Certificate

```
Subject: Let's Encrypt R3
Issued by: ISRG Root X2 (Root CA)
```

**Important:**
❌ The server **does NOT send the root certificate**
✔ Because the browser ALREADY has the root certificate installed.

---

# ⭐ **STEP 2 — Browser Starts Certificate Verification Process**

The browser now performs a **full chain-of-trust validation**.

We will break it down **in extreme detail**.

---

# STEP 3 — Verify LEAF Certificate (pinkbank.com)

## 🔍 3.1 Extract info from leaf cert

Browser reads:

* Subject (who owns cert) → `pinkbank.com`
* Issuer (who signed it) → `Let's Encrypt R3`
* Public Key of pinkbank.com
* Signature on the certificate

## 3.2 Check domain name match

Browser checks:

```
Does CN or SAN contain pinkbank.com?
```

✔ Must match the domain user typed.

If someone tries:

```
fakebank.com certificate → used for pinkbank.com
```

❌ Browser immediately blocks.

---

## 3.3 Verify the signature on leaf certificate

Every certificate has this structure:

```
[ Data ]
[ Signature created using issuer’s PRIVATE key ]
```

To verify:

Browser uses **Intermediate CA’s PUBLIC key** (from R3 certificate).

### Browser performs:

```
Verify ( signature_of_leaf_cert, public_key_of_Intermediate_CA )
```

If correct:

✔ Confirms that Intermediate CA actually signed the leaf certificate
✔ Confirms certificate was not modified
✔ Confirms certificate is genuine

If wrong → ❌ browser blocks immediately ("certificate not trusted").

---

# STEP 4 — Verify Intermediate CA certificate

Now browser moves one step up the chain.

Intermediate CA = R3 (or E1 depending on chain)

Inside Intermediate CA certificate:

* Subject: R3
* Issuer: ISRG Root X2
* Signature: signed by ISRG Root X2 using its private key
* Public Key of R3

## 4.1 Browser checks:

```
Is intermediate certificate signed by a trusted root?
```

It now checks **its own trust store**.

Every OS/browser includes 150+ trusted root certificates.

Examples:

* Let’s Encrypt ISRG Root X1/X2
* DigiCert High Assurance Root
* Sectigo Root CA
* Google Trust Services Root

Browser searches for:

```
ISRG Root X2
```

If present → continue
If not → certificate not trusted

---

## 4.2 Verify signature on the Intermediate CA certificate

Browser grabs:

* ISRG Root X2 public key (from trust store)
* Signature on Intermediate certificate

Runs:

```
Verify ( signature_of_intermediate_cert, public_key_of_root_CA )
```

If signature is valid:

✔ Confirms Intermediate CA certificate is genuine
✔ Not tampered
✔ Was issued by a trusted root
✔ Safe to trust

---

# STEP 5 — Verify Root CA Trust

Root CA certificates are **self-signed**.
Meaning:

```
Issuer = Subject
```

Example:

```
Subject: ISRG Root X2
Issuer: ISRG Root X2
```

The browser checks:

### 🔍 Is this root in my trust store?

YES → ✔ trusted
NO → ❌ invalid certificate chain

Root CA itself is NOT validated cryptographically —
**It is trusted because the OS/browser explicitly trusts it.**

---

# ⭐ STEP 6 — Build the Certificate Chain

Browser constructs a trust chain:

```
pinkbank.com (leaf cert)
    ⬅ Verified with Intermediate CA public key
Intermediate CA (R3 / E1)
    ⬅ Verified with Root CA public key
Root CA (ISRG Root X2)
    ✔ Already trusted in browser
```

If **EVERY link** is valid → the chain is trusted.

---

# ⭐ STEP 7 — Additional Checks

### 🔍 7.1 Expiry Date

Browser checks:

* leaf cert expiry
* intermediate CA expiry
* root CA expiry

If any expired → ❌ warning.

---

### 🔍 7.2 Revocation Check (OCSP / CRL)

Browser checks if the cert was revoked:

* OCSP request:
  Browser → CA: “Is this cert revoked?”
* CRL (Certificate Revocation List)

If revoked → ❌ blocked.

---

# ⭐ STEP 8 — Final Decision

If all checks pass:

✔ Certificate belongs to pinkbank.com
✔ Signed by Intermediate CA
✔ Intermediate CA is trusted because Root CA is trusted
✔ Root CA is trusted by browser
✔ No expiry
✔ Not revoked
✔ Domain matches

---

# ✅ **1. Where Root CA Certificates Are Stored in Your Browser**

Browsers contain a **built-in trust store** OR use the **OS trust store** depending on the browser.

| Browser                           | Uses Own Trust Store?     | Uses OS Trust Store?             |
| --------------------------------- | ------------------------- | -------------------------------- |
| **Google Chrome (Windows/Linux)** | ❌                         | ✔ Yes (Windows / Linux OS store) |
| **Google Chrome (macOS)**         | ✔ Yes                     | ✔ Yes                            |
| **Mozilla Firefox**               | ✔ Yes (Independent store) | ❌                                |
| **Microsoft Edge**                | ❌                         | ✔ Yes (uses Windows Store)       |

---

# 🔥 **2. PRACTICAL EXERCISES — CHECK ROOT CA IN YOUR BROWSER**

## 🟦 **A) Google Chrome (Windows/Linux)**

Chrome uses OS trust store.

### **Steps**

1. Open Chrome
2. Go to address bar and type:

```
chrome://settings/security
```

3. Scroll → **Advanced → Manage Certificates**
   OR Direct shortcut:

```
chrome://settings/certificates
```

4. You will see tabs:

   * *Your Certificates*
   * *Servers*
   * *Authorities*  ← **THIS contains ROOT + INTERMEDIATE CAs**

5. Click **Authorities**

6. Scroll and find:

```
ISRG Root X1
ISRG Root X2
DigiCert Root
Sectigo Root
GlobalSign Root
Amazon Root
Google Trust Services
```

### ✔ **That’s your browser’s ROOT store**

These certificates validate TLS chains.

---

## 🟧 **B) Mozilla Firefox (Independent Trust Store)**

Firefox manages its own CA database (NSS DB).

### **Steps**

1. Open Firefox
2. Go to address bar:

```
about:preferences#privacy
```

3. Scroll → **Certificates**
4. Click **View Certificates**
5. Go to **Authorities** tab

You will see:

```
ISRG Root X1
ISRG Root X2
Let's Encrypt Authority X3 (old)
```

And many others.

➡ Firefox always sends intermediate certificates, never the root.

---

## 🟩 **C) Microsoft Edge (Windows)**

Edge uses Windows OS store.

### Steps:

1. Open Edge
2. Visit:

```
edge://settings/privacy
```

3. Scroll down → **Manage Certificates**
   (or same as Chrome:

```
edge://settings/certificates
```

)

4. Go to **Trusted Root Certification Authorities**

---

# 🔥 PRACTICAL EXERCISE 1

## **View Let's Encrypt Root CA in Your Browser**

Follow these steps:

### Step 1: Open chrome://settings/certificates

Go to **Authorities** tab.

### Step 2: Search:

* **ISRG Root X1**
* **ISRG Root X2**

Click on it → You’ll see:

```
Issued to: ISRG Root X1
Issued by: ISRG Root X1
Validity: 2015–2035
```

Look at:

* Signature Algorithm
* Key Usage
* Basic Constraints (CA=true)
* Fingerprints (SHA-256 / SHA-1)

This proves it is a **self-signed root certificate**.

---

# 🔥 PRACTICAL EXERCISE 2

## **Verify complete certificate chain for any website**

Example: Visit

```
https://letsencrypt.org
```

### Step 1 — Open Developer Tools

Press:

```
Ctrl + Shift + I
```

Then go to the **Security** tab.

### Step 2 — See Certificate Chain

You’ll see:

```
letsencrypt.org (Leaf cert)
  └── R3 (Intermediate CA)
        └── ISRG Root X1 (Root CA)
```

### Step 3 — Click each certificate

You can see:

* Issuer
* Subject
* Expiry
* Signature algorithm
* Public key

This is the EXACT chain browser verified.

---

# 🔥 PRACTICAL EXERCISE 3

## **Use Windows OS Trust Store to view Root CAs**

### Steps:

1. Press **Win + R**
2. Type:

```
certmgr.msc
```

3. Go to:

```
Trusted Root Certification Authorities → Certificates
```

Here you will find:

* ISRG Root X1
* DigiCert Root
* Amazon Root CA
* Microsoft Root CA
* GlobalSign Root
* Google Root CA

✔ These are the trust anchors (highest-level certificates).

---

# 🐧 BONUS — Linux Trust Store (Ubuntu / RHEL)

Linux stores root CAs under:

### **Ubuntu/Debian**

```
/etc/ssl/certs/
/usr/share/ca-certificates/
```

### **RedHat / CentOS / Fedora**
```
ls /etc/ssl/certs/
```

### Update trust:

```
sudo update-ca-certificates
```

---




---


## CLIENT-SIDE: How the Scheduler Authenticates to the API Server

In mutual TLS, the **client also needs to present its identity** — in this case, the scheduler must prove who it is to the API server.

---

### Step 1: How Does the Scheduler Authenticate Itself?

Open the same kubeconfig file used by the scheduler:

```bash
cat /etc/kubernetes/scheduler.conf
```

Look for:

```yaml
users:
- name: system:kube-scheduler
  user:
    client-certificate-data: <base64 encoded cert>
    client-key-data: <base64 encoded key>
```

These fields hold:

* `client-certificate-data` → the scheduler’s **public certificate**
* `client-key-data` → the corresponding **private key**

To decode and inspect the certificate:

```bash


echo -n "<client-certificate-data>" | base64 --decode > scheduler.crt
or
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' --kubeconfig=/etc/kubernetes/scheduler.conf | base64 --decode >scheduler.crt

openssl x509 -in scheduler.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 5396590023349466030 (0x4ae48a08ac2973ae)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 17 19:09:09 2026 GMT
        Subject: CN = system:kube-scheduler
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d1:5a:b8:b5:db:33:e5:bd:d1:ed:ae:3e:59:e9:
                    d2:64:bb:aa:29:a9:50:7a:6c:27:f6:54:ac:fa:62:
                    75:2b:2e:92:47:64:16:78:ec:2e:5e:aa:e0:e6:8c:
                    c2:4e:74:d7:10:57:19:f1:f4:f1:3b:ba:df:a8:cb:
                    cf:4e:30:0f:e0:5a:c4:72:c0:0b:e5:a6:84:fd:b0:
                    bb:78:ac:ec:4a:5a:a9:cc:60:61:88:9b:2c:1d:cb:
                    2e:1f:30:f4:4c:3b:c4:eb:b8:37:8b:26:1c:88:c3:
                    d6:f8:9e:61:6b:20:d4:07:b5:d8:04:e4:f4:c8:6c:
                    e2:73:7b:70:51:9f:67:54:34:5a:c7:f9:f6:7d:d5:
                    f2:d8:69:73:17:9a:51:6c:fe:f4:f8:3e:6b:43:89:
                    7b:16:d5:33:d5:52:4e:aa:9e:14:3f:fb:63:b1:2c:
                    ef:6e:e7:4e:8e:3d:0e:03:d9:5a:c7:55:8f:46:58:
                    d2:1e:e7:eb:2a:1e:a8:1b:66:58:d2:71:e6:71:33:
                    66:c8:c0:53:ae:69:1d:ee:c7:94:3b:80:66:0f:1e:
                    fb:6a:c3:ab:85:53:d8:c8:f7:03:78:65:1e:9d:0e:
                    b2:c5:1e:99:60:36:36:d8:9b:0e:6c:86:93:5d:5e:
                    21:d1:39:55:7f:e5:fa:16:98:6a:a9:43:a0:97:ce:
                    ff:c3
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        68:a1:55:39:4d:35:c9:3d:cb:d1:02:ee:19:85:da:bf:c3:c4:
        41:74:59:cf:45:d4:b0:93:b9:f3:a3:bc:02:7a:26:8d:6e:3c:
        55:55:7f:70:9d:90:4e:b0:cf:ee:0c:01:0f:49:11:6b:44:96:
        e9:ba:7c:cc:59:48:33:4a:f6:44:a6:27:47:63:3a:51:b2:4e:
        20:a9:55:fe:e7:38:a9:d7:8a:15:e0:50:69:ee:ef:70:d2:82:
        37:9f:46:f1:3d:2c:25:25:64:06:db:7b:07:67:6c:47:b7:36:
        d5:6a:b0:82:f0:72:94:51:92:8a:85:c0:b9:41:06:03:ea:cc:
        2a:6b:60:27:80:29:71:ca:43:02:2b:73:81:54:1a:13:28:84:
        90:f9:6b:23:66:10:1d:e8:34:38:60:ac:90:bf:65:ab:e4:01:
        fc:24:2c:f5:71:3a:91:62:80:fa:25:51:08:79:c4:32:d2:f5:
        88:f4:a2:e5:5d:6d:79:8c:e3:c4:e2:d0:53:fa:22:d1:00:a1:
        48:7d:40:eb:0c:ae:3e:3e:2b:51:19:81:45:d3:d8:55:91:c4:
        5e:ec:d3:87:63:db:c9:86:57:fe:0c:b5:8d:34:18:8f:7b:b8:
        65:d3:fd:79:90:0f:a8:20:f0:2c:8f:f4:7b:8a:2d:11:a3:10:
        b2:eb:04:bf
```

You should see something like:

```
Subject: CN=system:kube-scheduler
Issuer: CN=kubernetes
```

This confirms:

* The scheduler is identifying as `system:kube-scheduler`
* The certificate is signed by the **cluster CA**

---

### Step 2: How Does the API Server Verify the Scheduler?

To authenticate the client, the **API server must trust the CA** that signed the scheduler's certificate.

Check the API server manifest:

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Look for:

```yaml
--client-ca-file=/etc/kubernetes/pki/ca.crt
```

This tells us:

* The API server uses `/etc/kubernetes/pki/ca.crt` to **validate client certificates**
* Since the scheduler’s certificate is signed by this CA, the API server **accepts and trusts** it

---

## Conclusion: Focus on Config Files, Not Hardcoded Paths

Here’s what you should take away:

* You **don’t need to memorize** certificate file paths
* Instead, focus on the **config files**:

  * Static pod manifests (`/etc/kubernetes/manifests/`) for server-side config
  * Kubeconfig files (e.g. `scheduler.conf`) for client-side authentication

Everything flows from there.

---

### Summary Table

| Component  | What It Does                          | Where to Look                                   | What to Look For                                                           |
| ---------- | ------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------- |
| API Server | Presents TLS cert to clients          | `/etc/kubernetes/manifests/kube-apiserver.yaml` | `--tls-cert-file`, `--client-ca-file`                                      |
| Scheduler  | Verifies server, presents client cert | `/etc/kubernetes/scheduler.conf`                | `certificate-authority-data`, `client-certificate-data`, `client-key-data` |

---

## Example 2: mTLS Between API Server (Client) and etcd (Server)

![Alt text](/images/33c.png)

In this example, we’ll examine how **mutual TLS (mTLS)** works between the **kube-apiserver** (client) and **etcd** (server). We'll again use the principle of inspecting **configuration files** rather than memorizing certificate paths.

This reinforces the idea that once you know **where to look**, you can figure out **how any TLS-secured communication** works inside Kubernetes.

---

## SERVER-SIDE: etcd Presents Its Certificate to API Server

### Step 1: Know Who’s the Server

In this scenario:

* **etcd** is the **server**
* **kube-apiserver** is the **client**

The server (etcd) must present a valid TLS certificate to the API server, and the API server must verify it.

---

### Step 2: Where Is etcd's Certificate Defined?

We know from [Day 15](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025/tree/main/Day%2015) that etcd runs as a **static pod**. So, inspect the etcd manifest:

```bash
cat /etc/kubernetes/manifests/etcd.yaml
```
Look for the following flags:

```yaml
--cert-file=/etc/kubernetes/pki/etcd/server.crt
--key-file=/etc/kubernetes/pki/etcd/server.key
--client-cert-auth=true
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```
```bash
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubeadm.kubernetes.io/etcd.advertise-client-urls: https://172.30.1.2:2379
  labels:
    component: etcd
    tier: control-plane
  name: etcd
  namespace: kube-system
spec:
  containers:
  - command:
    - etcd
    - --advertise-client-urls=https://172.30.1.2:2379
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt
    - --client-cert-auth=true
    - --data-dir=/var/lib/etcd
    - --feature-gates=InitialCorruptCheck=true
    - --initial-advertise-peer-urls=https://172.30.1.2:2380
    - --initial-cluster=controlplane=https://172.30.1.2:2380
    - --key-file=/etc/kubernetes/pki/etcd/server.key
    - --listen-client-urls=https://127.0.0.1:2379,https://172.30.1.2:2379
    - --listen-metrics-urls=http://127.0.0.1:2381
    - --listen-peer-urls=https://172.30.1.2:2380
    - --name=controlplane
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    - --peer-client-cert-auth=true
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --snapshot-count=10000
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --watch-progress-notify-interval=5s
    image: registry.k8s.io/etcd:3.6.4-0
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 8
      httpGet:
        host: 127.0.0.1
        path: /livez
        port: probe-port
        scheme: HTTP
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    name: etcd
    ports:
    - containerPort: 2381
      name: probe-port
      protocol: TCP
    readinessProbe:
      failureThreshold: 3
      httpGet:
        host: 127.0.0.1
        path: /readyz
        port: probe-port
        scheme: HTTP
      periodSeconds: 1
      timeoutSeconds: 15
    resources:
      requests:
        cpu: 25m
        memory: 100Mi
    startupProbe:
      failureThreshold: 24
      httpGet:
        host: 127.0.0.1
        path: /readyz
        port: probe-port
        scheme: HTTP
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /var/lib/etcd
      name: etcd-data
    - mountPath: /etc/kubernetes/pki/etcd
      name: etcd-certs
  hostNetwork: true
  priority: 2000001000
  priorityClassName: system-node-critical
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - hostPath:
      path: /etc/kubernetes/pki/etcd
      type: DirectoryOrCreate
    name: etcd-certs
  - hostPath:
      path: /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data
status: {}
```

This tells us:

* etcd uses `/etc/kubernetes/pki/etcd/server.crt` as its TLS certificate.
* It trusts only client certificates signed by `/etc/kubernetes/pki/etcd/ca.crt`.

Inspect the certificate:

```bash
openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 8832452172654244788 (0x7a932c7466aef3b4)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = etcd-ca
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 17 19:09:09 2026 GMT
        Subject: CN = controlplane
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c2:03:83:bc:42:bf:b5:92:65:99:71:43:90:23:
                    20:d0:fd:f8:47:3d:05:0d:cf:ff:89:b9:f5:b6:1d:
                    ae:34:21:fd:f1:11:c1:22:98:78:91:56:0c:35:aa:
                    6e:75:84:24:5f:6c:76:69:cb:31:8d:b6:67:9e:4c:
                    91:4f:88:04:49:08:75:67:e4:c5:61:46:72:1b:98:
                    0c:45:e4:b8:ed:f7:18:38:85:2f:34:a2:1b:ed:93:
                    81:34:7a:33:43:cd:bf:81:ea:d6:55:db:03:86:1d:
                    6a:86:2b:4c:44:02:69:3b:91:2e:18:db:a5:d0:6c:
                    b1:0e:0d:4b:85:ab:fd:d3:56:e0:2d:a9:44:67:98:
                    35:1c:d1:95:94:d5:12:82:3b:e0:82:1b:18:a5:ad:
                    26:fb:56:84:ee:b3:05:9f:0e:89:68:55:c9:25:f6:
                    ff:d1:8b:e6:15:98:66:1d:29:0e:53:d6:79:e3:c3:
                    6f:57:2a:5e:b5:84:9d:64:96:94:02:b3:97:50:06:
                    5a:1a:68:5f:a9:91:31:26:14:15:55:ac:48:aa:8a:
                    73:26:ce:24:f1:89:a9:d5:35:44:d3:e1:fb:27:02:
                    95:02:da:88:5a:ef:47:1e:75:9d:ce:a7:40:60:6a:
                    fd:f6:85:2a:37:2d:1e:3e:23:eb:72:43:8d:62:15:
                    22:b9
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                E6:FA:74:F2:6E:D6:17:41:9A:56:3E:85:F4:B4:AB:FF:7A:33:E4:A5
            X509v3 Subject Alternative Name: 
                DNS:controlplane, DNS:localhost, IP Address:172.30.1.2, IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        53:da:fa:ff:56:28:aa:88:39:4e:9d:20:bd:75:af:f6:69:3e:
        29:5a:b4:05:5c:90:d0:00:9e:11:83:55:1d:3f:5b:a0:23:63:
        ba:df:e9:c3:f6:f4:44:df:61:7f:d2:d0:fb:65:bd:4b:19:8d:
        50:44:cd:6c:2b:92:0e:e6:30:2d:15:f5:74:f4:91:55:bd:7c:
        00:d7:ce:6b:4c:dd:0f:65:c8:7f:6a:f1:4c:87:d5:fc:e2:9e:
        59:15:75:cf:1f:6d:10:6c:5d:6d:36:a4:0f:d9:87:6d:7a:3a:
        48:58:fd:21:42:dc:c5:d6:84:4f:ff:00:5d:32:49:d3:8e:f9:
        f3:24:63:7f:e3:07:13:16:26:e8:92:aa:2b:61:30:c4:28:e0:
        86:18:c3:1c:15:18:38:a2:de:06:0a:1a:4b:f3:4d:65:a0:0c:
        ef:25:f4:5e:bd:40:30:b4:6b:87:76:85:e9:39:d4:72:8d:25:
        3f:37:41:1d:31:b3:90:12:c8:df:15:99:34:6e:bf:e1:1b:db:
        65:5c:8a:3a:54:af:e2:df:00:3b:f3:09:af:a7:14:5a:7c:a2:
        1b:ba:77:5b:98:a6:0a:a5:fd:11:63:9a:5b:a0:3c:de:73:19:
        28:ca:7d:83:45:10:a3:f5:56:7e:bf:ac:51:de:09:24:07:1a:
        40:d1:2c:22
```

You should see:

* **Subject:** `CN=controlplane` (matching the control plane hostname)
* **Issuer:** `CN=etcd-ca` (or possibly `CN=kubernetes`, depending on your setup)

This confirms:

* etcd is identifying itself as `controlplane`
* It’s using a certificate signed by a trusted Certificate Authority (CA)

---

### Step 3: How Does the API Server Verify etcd's Certificate?

Since the **API server is the client**, it needs to verify the certificate presented by etcd. To do this, it must trust the **CA that signed etcd’s server certificate**.

Check the API server’s static pod manifest:

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```
Look for these flags:
```yaml
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
```
The `--etcd-cafile` flag tells us:
* The API server uses `/etc/kubernetes/pki/etcd/ca.crt` to verify etcd’s server certificate.
* This CA file must match the **issuer** of the certificate that etcd presents (i.e., `CN=etcd-ca`).

```bash
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 172.30.1.2:6443
  labels:
    component: kube-apiserver
    tier: control-plane
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=172.30.1.2
    - --allow-privileged=true
    - --authorization-mode=Node,RBAC
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --enable-admission-plugins=NodeRestriction
    - --enable-bootstrap-token-auth=true
    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
    - --etcd-servers=https://127.0.0.1:2379
    - --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
    - --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
    - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
    - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
    - --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
    - --requestheader-allowed-names=front-proxy-client
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --requestheader-extra-headers-prefix=X-Remote-Extra-
    - --requestheader-group-headers=X-Remote-Group
    - --requestheader-username-headers=X-Remote-User
    - --secure-port=6443
    - --service-account-issuer=https://kubernetes.default.svc.cluster.local
    - --service-account-key-file=/etc/kubernetes/pki/sa.pub
    - --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
    - --service-cluster-ip-range=10.96.0.0/12
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
    image: registry.k8s.io/kube-apiserver:v1.34.1
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 8
      httpGet:
        host: 172.30.1.2
        path: /livez
        port: probe-port
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    name: kube-apiserver
    ports:
    - containerPort: 6443
      name: probe-port
      protocol: TCP
    readinessProbe:
      failureThreshold: 3
      httpGet:
        host: 172.30.1.2
        path: /readyz
        port: probe-port
        scheme: HTTPS
      periodSeconds: 1
      timeoutSeconds: 15
    resources:
      requests:
        cpu: 50m
    startupProbe:
      failureThreshold: 24
      httpGet:
        host: 172.30.1.2
        path: /livez
        port: probe-port
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ca-certs
      readOnly: true
    - mountPath: /etc/ca-certificates
      name: etc-ca-certificates
      readOnly: true
    - mountPath: /etc/kubernetes/pki
      name: k8s-certs
      readOnly: true
    - mountPath: /usr/local/share/ca-certificates
      name: usr-local-share-ca-certificates
      readOnly: true
    - mountPath: /usr/share/ca-certificates
      name: usr-share-ca-certificates
      readOnly: true
  hostNetwork: true
  priority: 2000001000
  priorityClassName: system-node-critical
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - hostPath:
      path: /etc/ssl/certs
      type: DirectoryOrCreate
    name: ca-certs
  - hostPath:
      path: /etc/ca-certificates
      type: DirectoryOrCreate
    name: etc-ca-certificates
  - hostPath:
      path: /etc/kubernetes/pki
      type: DirectoryOrCreate
    name: k8s-certs
  - hostPath:
      path: /usr/local/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-local-share-ca-certificates
  - hostPath:
      path: /usr/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-share-ca-certificates
status: {}
```

Inspect it with:

```bash
openssl x509 -in /etc/kubernetes/pki/etcd/ca.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 7951818003303202979 (0x6e5a8857ed7180a3)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = etcd-ca
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 15 19:09:09 2035 GMT
        Subject: CN = etcd-ca
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c6:72:6b:62:06:1c:b6:a9:53:52:70:2b:73:ab:
                    60:5b:b6:4f:6f:38:c5:2a:bb:f6:14:1a:0f:e0:a1:
                    9f:07:fa:95:b1:78:08:72:d8:97:fd:c8:ac:d6:39:
                    77:cb:87:ef:74:b4:8e:76:9d:83:14:3f:85:81:de:
                    da:03:5d:0a:9c:50:f9:4e:21:93:d3:68:da:f2:97:
                    21:9f:36:5d:ca:70:0d:fa:8d:56:63:82:31:75:58:
                    b5:f4:5e:4a:5a:e6:c8:a8:fc:17:08:aa:ca:32:4f:
                    11:01:6c:0b:c4:b3:d4:08:97:3e:88:90:4d:79:25:
                    27:cd:74:3d:a5:4d:d3:b2:de:77:15:2b:de:af:d3:
                    d0:f7:3b:74:e6:85:9d:3b:b4:6d:14:87:f0:a8:ca:
                    9a:dc:bf:01:b0:aa:64:d7:04:b1:4a:e9:a7:98:fc:
                    e6:71:d6:63:83:4b:e1:7f:40:98:36:27:f5:fe:b1:
                    fc:e8:03:48:62:98:74:7b:b3:df:af:f5:44:d7:7c:
                    26:da:42:9a:60:33:12:90:81:0c:ff:92:32:8a:37:
                    29:f7:74:d2:e6:64:84:49:00:de:12:c9:ac:5c:d1:
                    67:b6:8c:1c:fa:3d:3e:15:9d:a0:98:96:2c:d5:54:
                    0a:fc:5a:6d:33:e3:56:83:a9:5a:10:e3:f7:7e:46:
                    30:f5
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                E6:FA:74:F2:6E:D6:17:41:9A:56:3E:85:F4:B4:AB:FF:7A:33:E4:A5
            X509v3 Subject Alternative Name: 
                DNS:etcd-ca
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        09:a7:6a:35:54:3c:f6:f3:5a:04:d2:ff:cb:ce:17:90:13:94:
        d5:86:38:ca:80:c8:77:f9:1c:a6:72:05:71:da:2d:d1:4c:6c:
        d5:ec:99:59:e6:a0:38:3d:5b:b4:da:bb:3d:41:51:30:0a:3d:
        86:4f:38:3e:24:95:56:44:3a:6e:f3:f0:69:f5:dd:cc:37:c7:
        20:11:20:23:e1:89:64:10:83:25:23:1b:d9:2d:42:09:4d:fb:
        b9:17:18:c4:e4:33:08:c2:74:20:db:cc:bb:63:69:dc:8f:8a:
        e5:6b:7f:9e:14:7b:73:c7:64:1e:6b:d3:b1:ed:9c:8f:e9:c7:
        fe:eb:26:b9:e1:c9:09:79:bf:e7:e2:48:8e:d0:b9:5f:0a:73:
        d5:c7:03:b6:32:cb:bc:c8:aa:7b:4a:87:c0:4f:08:d5:c5:18:
        7c:5c:4f:1e:74:01:ec:7a:3d:94:4a:85:37:4c:23:c3:0b:6c:
        6f:0f:4c:71:19:bc:72:73:ce:e9:96:1e:00:9d:e4:3e:a5:57:
        e5:9e:a2:0c:de:2e:14:96:f8:18:8b:ab:b7:dc:d7:4b:87:e0:
        39:51:88:8b:5d:fc:fe:55:33:8e:a8:f6:e4:6e:22:3b:d8:14:
        8a:8e:38:39:ed:c9:0e:78:5b:d6:40:81:34:02:59:4c:64:66:
        7e:b7:95:48
```

You should see:

* **Subject:** `CN=etcd-ca`
* **Issuer:** `CN=etcd-ca` (self-signed)

This confirms:

* The API server **trusts the etcd-ca**, and that’s how it verifies the authenticity of etcd’s certificate during the TLS handshake.

---


## CLIENT-SIDE: API Server Authenticates to etcd

### Step 1: Where Does API Server Specify TLS Credentials?

Let’s inspect how the API server connects securely to etcd.

Check the static pod manifest:

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Look for the etcd-related TLS flags:

```yaml
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
```

Let’s break this down:

* `--etcd-cafile`: The **CA certificate** used by the API server to verify etcd’s identity.
* `--etcd-certfile`: The **client certificate** the API server presents to etcd.
* `--etcd-keyfile`: The **private key** associated with the above certificate.

Inspect the client certificate:

```bash
openssl x509 -in /etc/kubernetes/pki/apiserver-etcd-client.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 1220277121815901053 (0x10ef4b93b55f737d)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = etcd-ca
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 17 19:09:09 2026 GMT
        Subject: CN = kube-apiserver-etcd-client
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:bb:c8:d8:44:29:27:9f:f1:e0:e7:e6:b6:cb:50:
                    a3:0f:db:d4:0a:ec:81:50:4e:78:d9:db:65:0d:96:
                    cb:9e:08:41:f0:8b:62:8b:cf:57:f9:90:58:21:0f:
                    2e:52:56:a5:e7:6d:b4:8a:42:1e:c7:a4:0a:dd:eb:
                    81:41:95:75:21:bd:83:8c:4f:f8:af:4d:7d:22:74:
                    4c:8b:0c:fd:a2:e7:f6:0e:b2:89:cb:39:71:98:99:
                    aa:e5:cc:aa:de:f5:a9:bf:49:ee:26:70:30:ce:86:
                    ce:f4:6d:a0:a4:9b:ba:33:31:88:c5:17:d1:27:01:
                    00:35:4f:b6:ab:20:4e:25:fb:9a:d6:b2:15:5a:36:
                    a3:1b:e6:8c:8c:50:b2:61:9c:6a:77:c6:4c:6f:37:
                    5f:06:6f:5a:72:ee:32:2f:fe:c3:46:ae:54:ab:10:
                    34:0a:61:8c:cf:86:02:c8:23:6c:a1:b3:85:b6:50:
                    f8:1f:65:cf:ae:da:6c:06:70:9e:83:ea:b9:59:85:
                    b8:25:fd:81:5a:e6:85:15:d2:b3:04:77:fe:db:69:
                    21:7c:52:ea:5e:4e:c7:19:f4:69:ae:a2:31:12:62:
                    e8:33:7d:8e:80:27:e5:b1:76:69:00:fe:52:a5:b6:
                    bb:58:35:35:87:64:e0:af:49:c5:5a:9a:fe:0a:13:
                    9f:45
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                E6:FA:74:F2:6E:D6:17:41:9A:56:3E:85:F4:B4:AB:FF:7A:33:E4:A5
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        c4:91:1e:14:a9:97:1a:14:47:8f:f7:a8:14:b5:0a:65:3e:bf:
        52:4d:ba:6b:ab:f9:a7:4a:83:63:30:9a:10:a5:46:a4:d8:bc:
        50:0b:97:cb:a6:9a:6b:07:d5:f5:bc:3e:8b:6c:99:8c:81:40:
        d6:70:2e:ad:df:58:65:a5:1e:6f:cc:ec:c1:89:83:40:90:ef:
        e8:5e:3d:e0:8a:0b:44:d0:0d:74:c5:b6:57:8f:2c:9b:fd:9a:
        8a:03:02:97:4b:a5:bd:38:20:01:4e:df:ea:2d:87:c4:28:83:
        5c:ab:90:26:df:a2:75:67:94:3d:da:24:16:a7:45:d3:23:86:
        db:72:59:01:02:a4:51:1a:b9:29:8c:a4:33:b3:a1:4d:23:85:
        93:9d:17:c5:a7:ed:b2:73:fa:5c:ac:7a:5a:5a:39:9c:f7:65:
        45:c7:52:25:a2:7c:0d:58:03:13:2f:b3:7d:27:f5:99:c9:e1:
        53:98:1f:6a:8d:5c:14:e5:00:0b:f3:a7:12:57:da:05:b9:90:
        57:1e:68:68:95:f5:d2:06:bb:8b:6d:a6:32:a0:c8:05:8d:e1:
        88:0d:de:6c:8d:df:1b:49:2a:57:a8:b2:22:fe:c8:e5:bd:a4:
        1f:b5:f7:38:6a:a3:f9:fd:3d:e9:af:a2:0b:e9:64:92:bf:81:
        ce:ee:0b:99
```

You should see:

* **Subject:** `CN=kube-apiserver-etcd-client`
* **Issuer:** `CN=etcd-ca`

This confirms:

* The API server authenticates to etcd using the identity `kube-apiserver-etcd-client`
* The certificate is signed by the **etcd-ca**, which etcd is configured to trust

---

### Step 2: How Does etcd Verify the API Server's Certificate?

Since **etcd is the server**, it must validate the client certificate presented by the API server.

Look at etcd’s static pod manifest:

```bash
cat /etc/kubernetes/manifests/etcd.yaml
```

Look for this flag:

```yaml
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

This tells us:

* etcd will **only accept client certificates** that are signed by the **CA in `etcd/ca.crt`** — which is the same CA that issued the API server’s `kube-apiserver-etcd-client` certificate.

So:

* etcd uses `--trusted-ca-file` to verify the API server’s certificate.
* The certificate is trusted because it’s signed by the `etcd-ca`.

etcd cert is root certificate and root certificates is always the self signed.

```bash
openssl x509 -in /etc/kubernetes/pki/etcd/ca.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 7951818003303202979 (0x6e5a8857ed7180a3)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = etcd-ca
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 15 19:09:09 2035 GMT
        Subject: CN = etcd-ca
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c6:72:6b:62:06:1c:b6:a9:53:52:70:2b:73:ab:
                    60:5b:b6:4f:6f:38:c5:2a:bb:f6:14:1a:0f:e0:a1:
                    9f:07:fa:95:b1:78:08:72:d8:97:fd:c8:ac:d6:39:
                    77:cb:87:ef:74:b4:8e:76:9d:83:14:3f:85:81:de:
                    da:03:5d:0a:9c:50:f9:4e:21:93:d3:68:da:f2:97:
                    21:9f:36:5d:ca:70:0d:fa:8d:56:63:82:31:75:58:
                    b5:f4:5e:4a:5a:e6:c8:a8:fc:17:08:aa:ca:32:4f:
                    11:01:6c:0b:c4:b3:d4:08:97:3e:88:90:4d:79:25:
                    27:cd:74:3d:a5:4d:d3:b2:de:77:15:2b:de:af:d3:
                    d0:f7:3b:74:e6:85:9d:3b:b4:6d:14:87:f0:a8:ca:
                    9a:dc:bf:01:b0:aa:64:d7:04:b1:4a:e9:a7:98:fc:
                    e6:71:d6:63:83:4b:e1:7f:40:98:36:27:f5:fe:b1:
                    fc:e8:03:48:62:98:74:7b:b3:df:af:f5:44:d7:7c:
                    26:da:42:9a:60:33:12:90:81:0c:ff:92:32:8a:37:
                    29:f7:74:d2:e6:64:84:49:00:de:12:c9:ac:5c:d1:
                    67:b6:8c:1c:fa:3d:3e:15:9d:a0:98:96:2c:d5:54:
                    0a:fc:5a:6d:33:e3:56:83:a9:5a:10:e3:f7:7e:46:
                    30:f5
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                E6:FA:74:F2:6E:D6:17:41:9A:56:3E:85:F4:B4:AB:FF:7A:33:E4:A5
            X509v3 Subject Alternative Name: 
                DNS:etcd-ca
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        09:a7:6a:35:54:3c:f6:f3:5a:04:d2:ff:cb:ce:17:90:13:94:
        d5:86:38:ca:80:c8:77:f9:1c:a6:72:05:71:da:2d:d1:4c:6c:
        d5:ec:99:59:e6:a0:38:3d:5b:b4:da:bb:3d:41:51:30:0a:3d:
        86:4f:38:3e:24:95:56:44:3a:6e:f3:f0:69:f5:dd:cc:37:c7:
        20:11:20:23:e1:89:64:10:83:25:23:1b:d9:2d:42:09:4d:fb:
        b9:17:18:c4:e4:33:08:c2:74:20:db:cc:bb:63:69:dc:8f:8a:
        e5:6b:7f:9e:14:7b:73:c7:64:1e:6b:d3:b1:ed:9c:8f:e9:c7:
        fe:eb:26:b9:e1:c9:09:79:bf:e7:e2:48:8e:d0:b9:5f:0a:73:
        d5:c7:03:b6:32:cb:bc:c8:aa:7b:4a:87:c0:4f:08:d5:c5:18:
        7c:5c:4f:1e:74:01:ec:7a:3d:94:4a:85:37:4c:23:c3:0b:6c:
        6f:0f:4c:71:19:bc:72:73:ce:e9:96:1e:00:9d:e4:3e:a5:57:
        e5:9e:a2:0c:de:2e:14:96:f8:18:8b:ab:b7:dc:d7:4b:87:e0:
        39:51:88:8b:5d:fc:fe:55:33:8e:a8:f6:e4:6e:22:3b:d8:14:
        8a:8e:38:39:ed:c9:0e:78:5b:d6:40:81:34:02:59:4c:64:66:
        7e:b7:95:48`

```

---

### How Mutual TLS (mTLS) Works Here

* **etcd (server)** presents `server.crt`, and **API server (client)** verifies it using `--etcd-cafile`
* **API server (client)** presents `apiserver-etcd-client.crt`, and **etcd (server)** verifies it using `--trusted-ca-file`

This is **mutual TLS** — both components **authenticate each other** using certificates.

---

### Takeaway: Focus on Flags, Not File Paths

You don’t need to memorize paths. What matters is:

* Who is the **client**, who is the **server**
* Which component is **presenting** a certificate
* Which component is **validating** that certificate via a **trusted CA**

The static pod manifests show you everything you need.

---

### Summary Table

| Component      | Role   | Where to Look                                   | What to Look For                                     |
| -------------- | ------ | ----------------------------------------------- | ---------------------------------------------------- |
| etcd           | Server | `/etc/kubernetes/manifests/etcd.yaml`           | `--cert-file`, `--key-file`, `--trusted-ca-file`     |
| kube-apiserver | Client | `/etc/kubernetes/manifests/kube-apiserver.yaml` | `--etcd-cafile`, `--etcd-certfile`, `--etcd-keyfile` |

---


## Example 3: mTLS Between API Server (Client) and Kubelet (Server)

![Alt text](/images/33c.png)

In this example, we will explore **how mutual TLS (mTLS)** works between the **API server** (client) and the **kubelet** (server).

This is a vital communication channel, especially for actions like executing commands in a pod (`kubectl exec`), fetching logs (`kubectl logs`), and metrics collection — all of which require the API server to securely interact with the kubelet running on each node.

Like before, we'll **discover certificate paths and roles by reading configuration files**, rather than relying on memorization.

---

## Who is the Client and Who is the Server?

* **API Server** → acts as the **client**
* **Kubelet** → acts as the **server**

---

## SERVER-SIDE: How the Kubelet Presents Its Certificate

Before diving in, it's important to understand:

> Unlike the API server, controller manager, etcd, or scheduler — **the kubelet does not run as a Pod**.
> It runs as a **systemd-managed process** on the node and is typically located at `/usr/bin/kubelet`.
> That means there’s no Pod manifest to inspect — instead, we must look at the **process arguments** to understand where kubelet stores its certificates and config.

---

### Step 1: Locate the Kubelet Process

Start by checking how kubelet is launched:

```bash
ps -ef | grep kubelet

root        1563       1  1 18:01 ?        00:00:42 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --pod-infra-container-image=registry.k8s.io/pause:3.10.1 --container-runtime-endpoint unix:///run/containerd/containerd.sock --cgroup-driver=systemd --eviction-hard imagefs.available<5%,memory.available<100Mi,nodefs.available<5% --fail-swap-on=false
root        1812    1643  1 18:01 ?        00:01:18 kube-apiserver --advertise-address=172.30.1.2 --allow-privileged=true --authorization-mode=Node,RBAC --client-ca-file=/etc/kubernetes/pki/ca.crt --enable-admission-plugins=NodeRestriction --enable-bootstrap-token-auth=true --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key --etcd-servers=https://127.0.0.1:2379 --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key --requestheader-allowed-names=front-proxy-client --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt --requestheader-extra-headers-prefix=X-Remote-Extra- --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --secure-port=6443 --service-account-issuer=https://kubernetes.default.svc.cluster.local --service-account-key-file=/etc/kubernetes/pki/sa.pub --service-account-signing-key-file=/etc/kubernetes/pki/sa.key --service-cluster-ip-range=10.96.0.0/12 --tls-cert-file=/etc/kubernetes/pki/apiserver.crt --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
root       35651   14172  0 19:08 pts/0    00:00:00 grep --color=auto kubelet
```

In the output, you’ll typically find a flag like:

```bash
--config=/var/lib/kubelet/config.yaml
```

This tells us that kubelet is using the config file at:

```bash
/var/lib/kubelet/config.yaml
```

From this, we learn an important principle:

> The presence of the config file at `/var/lib/kubelet/config.yaml` strongly suggests that **kubelet-related files (certs, kubeconfigs, etc.) are stored under `/var/lib/kubelet/`**.

Even if the `config.yaml` doesn’t explicitly list `certDirectory`, you can navigate to:

```bash
/var/lib/kubelet/pki/
```
pki --> public key infrastructure

Inside this directory, you’ll typically find:

| File                             | Purpose                                             |
| -------------------------------- | --------------------------------------------------- |
| `kubelet.crt`                    | Server certificate (when kubelet acts as a server)  |
| `kubelet.key`                    | Private key for `kubelet.crt`                       |
| `kubelet-client-current.pem`     | Client cert (used when kubelet talks to API server) |
| `kubelet-client-<timestamp>.pem` | Rotated historical client certs                     |

For **server-side TLS**, the file of interest is:

```bash
/var/lib/kubelet/pki/kubelet.crt
```

This is the certificate the **kubelet presents when the API server connects to it** — such as during `kubectl exec`, `logs`, etc.

---

### Step 2: Inspect the Server Certificate

We're interested in how kubelet identifies itself as a **server**, so inspect:

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 6383559993221664800 (0x5896f5fe065f5020)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = controlplane-ca@1763406566
        Validity
            Not Before: Nov 17 18:09:26 2025 GMT
            Not After : Nov 17 18:09:26 2026 GMT
        Subject: CN = controlplane@1763406566
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:df:87:d5:c6:c7:5e:a9:62:46:76:f8:10:55:65:
                    f4:f3:9d:2d:c8:e2:ab:49:56:1f:94:b9:44:01:e9:
                    86:44:c0:e9:41:11:a8:02:5b:7e:f5:c4:2e:d3:85:
                    93:f6:da:0c:f9:42:d9:a3:92:46:74:10:80:2c:0e:
                    8a:0a:9e:3f:cb:8b:79:a0:6b:aa:32:a0:3d:a8:2f:
                    0e:63:4b:c8:32:5e:96:92:9a:44:53:a1:33:c2:65:
                    45:1d:9a:ac:39:76:a4:3e:ed:45:3a:c5:4a:12:6b:
                    50:6b:cb:36:d8:a4:b1:c2:8a:8f:ae:b4:37:3b:ff:
                    f9:27:61:89:57:e3:65:5e:05:e3:78:10:9e:57:04:
                    af:fd:69:86:f6:71:9f:87:9b:f0:e9:85:52:e5:88:
                    28:a6:3e:56:b2:94:51:82:69:30:22:ef:6f:13:c9:
                    51:18:a4:70:0e:fc:e4:90:6e:c9:1e:cb:ea:bb:ee:
                    15:7e:c4:4c:6a:28:50:ff:42:c8:80:2b:67:35:24:
                    e5:b1:1e:b3:06:0f:de:0e:3f:41:01:0f:54:1c:55:
                    a4:84:49:b7:64:71:19:bc:29:d4:fb:13:8c:e0:24:
                    00:a1:12:6f:c6:7c:bc:f3:1a:7e:61:fd:a1:4d:4d:
                    37:34:85:cb:0d:4c:fc:18:92:ef:b3:c7:85:c6:f0:
                    c1:b5
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                1D:B2:94:C6:C8:16:2F:C1:CA:D3:E4:CE:99:FB:35:2E:5D:C4:D8:57
            X509v3 Subject Alternative Name: 
                DNS:controlplane
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        06:64:40:f5:37:9f:a4:af:f5:32:a6:48:9d:91:70:06:cb:b8:
        f2:fc:b9:e4:49:07:a6:4a:8f:1a:fa:2c:1d:68:43:39:b5:de:
        31:44:bf:8f:ab:f8:f3:7f:3c:6c:33:10:f6:39:49:a9:e5:65:
        55:dd:46:01:40:74:9d:a6:c5:8b:c2:21:a2:48:55:4a:f1:d8:
        aa:f4:0a:aa:e0:2e:6b:84:c6:4f:f6:20:6c:70:57:9c:14:e6:
        f8:6f:f3:1d:2a:eb:ba:b7:7c:26:6a:ea:a9:a5:36:0b:f5:93:
        1a:46:4e:c5:ef:29:61:de:c0:33:7a:6e:1d:60:98:b2:65:f5:
        fd:b5:a9:5d:b0:f6:78:0e:c1:43:26:65:f3:7b:c7:d8:ac:eb:
        57:8b:8b:b9:16:67:01:d7:e7:41:d7:30:77:5b:47:00:e7:1a:
        14:c2:99:c1:ec:cf:68:3f:80:30:8f:89:5e:04:b9:8b:52:db:
        3d:0c:3d:f4:19:fb:ca:79:44:96:26:30:4a:69:f9:8d:0e:33:
        9d:9e:26:47:c9:79:80:96:f7:97:4a:bc:4f:ca:9d:78:98:f8:
        ce:48:2d:0a:04:46:63:0a:32:33:42:3e:6b:ed:88:3f:72:20:
        93:5b:5a:bf:d1:f0:8c:d4:bd:ca:ed:5f:f0:a2:42:44:af:84:
        db:c8:28:e8
```

You may find something like:

```
Subject: CN=controlplane@1763406566
Issuer: CN=controlplane-ca@1763406566
```

This confirms:

* The **Common Name (CN)** is `system:node:<node-name>`, showing it's a kubelet identity.
* It’s signed by a **cluster CA** named `my-second-cluster-control-plane-ca@1741433227`.

This is the **CA Kubernetes used to sign the kubelet’s server certificate** — ensuring trust.

---

###  How Did the Kubelet Get This Certificate?

Initially, the kubelet doesn’t have a certificate. Instead, it uses a **bootstrap token** to authenticate and request a signed certificate from the API server.

This mechanism is enabled in the API server by this flag:

```yaml
--enable-bootstrap-token-auth=true
```

So, kubelet starts by using a bootstrap token, gets authenticated by the API server, and then receives a **signed TLS certificate** — which becomes the `kubelet.crt`.

---

### Step 3: How the API Server Verifies the Kubelet (or Doesn’t)

In this connection, the **API server acts as the client**, initiating HTTPS requests to the kubelet. Normally, TLS clients verify the server’s certificate — but here’s what happens in Kubernetes:

Inspect the kubelet’s server certificate again:

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet.crt -text -noout
```

You’ll see:

```
Issuer: CN=my-second-cluster-control-plane-ca@1741433227
```

So the kubelet’s certificate is signed by a valid internal CA. But here’s the catch:

> The API server is **not configured to trust this CA**.

**API Server Trusts Kubelet: Asymmetric TLS**

Since the **API server already authenticated the kubelet during the bootstrap process using a bootstrap token**, and later **issued or approved its client certificate** (refer Note 2), it inherently trusts the kubelet’s identity.

As a result, **strict mutual TLS (mTLS) is not enforced** during API server to kubelet communication. Instead, what occurs is **asymmetric TLS**:  
- The **kubelet verifies the API server’s certificate**,  
- But the **API server does not strictly verify the kubelet’s certificate**.

> **Note:** Kubernetes can be hardened to enforce full mTLS with mutual certificate validation, but this is *not the default behavior* in most distributions like **kubeadm**, **GKE**, or **EKS**.

So while the **kubelet validates the API server**, the reverse is **not strictly true**.

> This isn’t full mutual TLS — and this asymmetry is a known behavior in kubeadm-based clusters.

After authenticating the kubelet, the API server enforces strict **authorization controls** using mechanisms like **RBAC, the Node authorizer, and NodeRestriction** to ensure secure and granular access. This layered approach reduces reliance on validating the kubelet’s TLS server certificate for trust, focusing instead on robust authorization policies.

---

**Note 2**
After the kubelet authenticates using a bootstrap token, it submits a **Certificate Signing Request (CSR)** to obtain a long-term **client certificate**.  
This certificate is **approved by the API server** (automatically or manually) and **signed by the cluster CA**.  
The kubelet then uses this certificate to **authenticate as a client** when communicating with the API server.
We will understand more about CSR in Part 4 (Day 34).

---

## CLIENT-SIDE: How the API Server Presents Its Own Certificate to the Kubelet

This is **mutual TLS**, so the API server must also **authenticate itself** to the kubelet.

In the `kube-apiserver` manifest, you’ll find:

```yaml
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
```

Inspect the client certificate:

```bash
openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 6679035053353594531 (0x5cb0b2fe7585eea3)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 17 19:09:09 2026 GMT
        Subject: O = kubeadm:cluster-admins, CN = kube-apiserver-kubelet-client
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:cd:87:8b:20:5c:6a:1d:79:25:e4:4e:6f:18:71:
                    49:9a:14:34:e0:cc:6a:2d:7f:75:3b:c6:ae:3e:1d:
                    3f:08:a8:55:2b:85:e7:0a:a7:50:bb:c2:bd:bb:c8:
                    20:7a:ae:d9:e4:ff:18:74:e2:bc:14:dc:9f:9f:2c:
                    b9:ab:ab:c6:c3:1e:c4:f0:84:a0:a5:9e:a0:e2:33:
                    92:24:a8:41:0e:b5:60:ca:75:3f:6d:40:63:77:b7:
                    11:2b:e7:73:1d:2a:a7:0c:4f:d2:eb:21:a1:bf:f5:
                    33:4e:55:5a:78:89:eb:cd:ba:63:90:f9:31:dd:95:
                    c5:98:40:50:1a:9e:58:92:e0:ec:9a:60:d3:3d:91:
                    2a:33:15:60:67:c8:f1:ed:84:d1:c3:f5:60:e9:1d:
                    ed:15:d0:15:52:98:aa:24:bb:2a:d0:f7:49:0c:d1:
                    d0:42:66:73:d9:54:65:a2:1a:e8:30:65:cb:bd:8e:
                    52:62:fa:1e:ab:f8:99:3b:12:ad:4d:28:f5:66:ed:
                    69:70:ed:6e:56:c2:dd:8a:51:fa:cf:9d:52:19:05:
                    36:c1:0f:f8:12:0e:73:f7:09:17:66:df:9e:9f:ca:
                    ae:b4:e3:5d:43:1f:de:51:77:c9:16:e0:db:62:39:
                    3a:b0:03:81:9e:7b:94:5c:c8:f0:51:dd:fa:9a:af:
                    72:21
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        65:86:d0:43:ba:91:6f:ae:3a:43:10:40:1a:a1:7b:9c:98:29:
        40:de:80:6a:2c:87:d6:30:03:75:90:bf:78:ff:9a:c0:31:18:
        2f:d4:e0:af:93:02:d9:c5:e4:91:71:9f:56:b2:e2:4e:fe:a9:
        7e:56:ca:54:54:a7:c2:90:d5:8b:33:81:83:c1:07:73:a4:fe:
        d8:b9:95:bf:65:32:09:de:0b:d8:2f:15:64:04:e4:fd:c7:8a:
        3c:a6:73:8d:9e:29:71:67:dc:1c:52:50:2d:62:a4:23:48:c1:
        a9:34:18:48:e9:b5:6c:7e:fa:d6:10:ca:b1:df:10:a9:b3:15:
        e2:b4:07:94:5e:ba:ba:14:a1:54:a6:21:fe:12:34:76:64:d6:
        fa:ec:33:06:f9:ff:44:3b:ce:7f:77:ce:32:0b:7d:97:45:c0:
        bd:9e:a8:31:06:97:39:48:d9:09:1c:06:2a:0a:9a:96:36:34:
        30:85:e7:57:f0:31:fe:f1:ab:c9:2f:d1:49:3e:3a:62:e8:b1:
        25:c1:13:98:30:07:21:d5:ac:07:ad:05:11:17:36:6f:c3:1c:
        d9:15:41:1e:63:3f:23:b0:d9:ce:b5:6e:2e:82:7d:2e:8f:90:
        13:3e:c9:98:9c:4b:ea:83:2c:48:8f:11:ee:62:0d:30:60:6d:
        09:c9:ac:66
```

You’ll likely see something like:

```
Subject: CN=kube-apiserver-kubelet-client
Issuer: CN=kubernetes
```

This means:

* The API server presents itself as `kube-apiserver-kubelet-client`
* The certificate is issued by the **Kubernetes cluster CA**

---

### How the Kubelet Verifies the API Server's Certificate

To enforce authentication, the **kubelet must verify that the client (API server) is trusted**.

Open the kubelet config file:

```bash
cat /var/lib/kubelet/config.yaml

apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
cgroupDriver: systemd
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
cpuManagerReconcilePeriod: 0s
crashLoopBackOff: {}
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMaximumGCAge: 0s
imageMinimumGCAge: 0s
kind: KubeletConfiguration
logging:
  flushFrequency: 0
  options:
    json:
      infoBufferSize: "0"
    text:
      infoBufferSize: "0"
  verbosity: 0
memorySwap: {}
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
```

You’ll find:

```yaml
clientCAFile: /etc/kubernetes/pki/ca.crt
```
This tells us:
* The kubelet uses `/etc/kubernetes/pki/ca.crt` as its **client certificate authority**
* Any client (like the API server) presenting a certificate must be **signed by this CA**

So when the API server connects and presents its certificate:

* Subject: `CN=kube-apiserver-kubelet-client`
* Issuer: The CA in `/etc/kubernetes/pki/ca.crt`

The kubelet validates the certificate using this CA file and accepts the connection.

> This is how **certificate-based client authentication** is enforced on the kubelet side.

---

## Summary: mTLS Between API Server and Kubelet

| Role       | Component  | Certificate File                                   | Notes                                                     |
| ---------- | ---------- | -------------------------------------------------- | --------------------------------------------------------- |
| Server     | Kubelet    | `/var/lib/kubelet/pki/kubelet.crt`                 | Signed by `my-second-cluster-control-plane-ca@1741433227` |
| Client     | API Server | `/etc/kubernetes/pki/apiserver-kubelet-client.crt` | Presented to kubelet to authenticate                      |
| Trust Root | Kubelet    | `/etc/kubernetes/pki/ca.crt`                       | Used to verify API server’s client certificate            |
| (Optional) | API Server | *Not enforced*                                     | Does not strictly verify the kubelet’s certificate        |

---

##  Recap: How mTLS Happens Here

1. The **kubelet** starts with a **bootstrap token**, then obtains a **server certificate** signed by the cluster CA.
2. The **API server connects** to the kubelet, and although no strict verification is enforced, the kubelet's certificate may be validated **implicitly** if the TLS library uses `/etc/kubernetes/pki/ca.crt`.
3. The **API server presents its client certificate** (`apiserver-kubelet-client.crt`) to the kubelet.
4. The **kubelet verifies** this certificate against its configured CA (`clientCAFile: /etc/kubernetes/pki/ca.crt`).
5. **mTLS is established** — although only the kubelet strictly verifies the peer’s certificate.

---

##  Tasks for You

Now that you’ve seen how mTLS works between core Kubernetes components, here are **3 hands-on tasks** to apply what you’ve learned:

#### Task 1: Controller Manager (Client) → API Server (Server)

This is similar to Example 1 (Scheduler → API Server).
Your goal:

* Identify the certificate the **Controller Manager** uses as a client.
* Verify the **API Server’s certificate and CA** used on the server side.
* Confirm how trust is established.

Hint: Start by checking the `kube-controller-manager` manifest file.

```bash
cat /etc/kubernetes/manifests/kube-controller-manager.yaml 

apiVersion: v1
kind: Pod
metadata:
  labels:
    component: kube-controller-manager
    tier: control-plane
  name: kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-controller-manager
    - --allocate-node-cidrs=true
    - --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --bind-address=127.0.0.1
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --cluster-cidr=192.168.0.0/16
    - --cluster-name=kubernetes
    - --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
    - --cluster-signing-key-file=/etc/kubernetes/pki/ca.key
    - --controllers=*,bootstrapsigner,tokencleaner
    - --kubeconfig=/etc/kubernetes/controller-manager.conf
    - --leader-elect=true
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --root-ca-file=/etc/kubernetes/pki/ca.crt
    - --service-account-private-key-file=/etc/kubernetes/pki/sa.key
    - --service-cluster-ip-range=10.96.0.0/12
    - --use-service-account-credentials=true
    image: registry.k8s.io/kube-controller-manager:v1.34.1
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 8
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: probe-port
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    name: kube-controller-manager
    ports:
    - containerPort: 10257
      name: probe-port
      protocol: TCP
    resources:
      requests:
        cpu: 25m
    startupProbe:
      failureThreshold: 24
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: probe-port
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ca-certs
      readOnly: true
    - mountPath: /etc/ca-certificates
      name: etc-ca-certificates
      readOnly: true
    - mountPath: /usr/libexec/kubernetes/kubelet-plugins/volume/exec
      name: flexvolume-dir
    - mountPath: /etc/kubernetes/pki
      name: k8s-certs
      readOnly: true
    - mountPath: /etc/kubernetes/controller-manager.conf
      name: kubeconfig
      readOnly: true
    - mountPath: /usr/local/share/ca-certificates
      name: usr-local-share-ca-certificates
      readOnly: true
    - mountPath: /usr/share/ca-certificates
      name: usr-share-ca-certificates
      readOnly: true
  hostNetwork: true
  priority: 2000001000
  priorityClassName: system-node-critical
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - hostPath:
      path: /etc/ssl/certs
      type: DirectoryOrCreate
    name: ca-certs
  - hostPath:
      path: /etc/ca-certificates
      type: DirectoryOrCreate
    name: etc-ca-certificates
  - hostPath:
      path: /usr/libexec/kubernetes/kubelet-plugins/volume/exec
      type: DirectoryOrCreate
    name: flexvolume-dir
  - hostPath:
      path: /etc/kubernetes/pki
      type: DirectoryOrCreate
    name: k8s-certs
  - hostPath:
      path: /etc/kubernetes/controller-manager.conf
      type: FileOrCreate
    name: kubeconfig
  - hostPath:
      path: /usr/local/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-local-share-ca-certificates
  - hostPath:
      path: /usr/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-share-ca-certificates
status: {}
```
```bash
kubectl config view --kubeconfig=/etc/kubernetes/controller-manager.conf

apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://172.30.1.2:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-controller-manager
  name: system:kube-controller-manager@kubernetes
current-context: system:kube-controller-manager@kubernetes
kind: Config
users:
- name: system:kube-controller-manager
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```
```bash
kubectl config view --raw --kubeconfig=/etc/kubernetes/controller-manager.conf -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
```
```bash
cat ca.crt 

-----BEGIN CERTIFICATE-----
MIIDBTCCAe2gAwIBAgIIS+e4qBFjcxIwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yNTExMTcxOTA0MDlaFw0zNTExMTUxOTA5MDlaMBUx
EzARBgNVBAMTCmt1YmVybmV0ZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQDXmZKhpdNDSE5ZORQSNpY983MLdRVYDNXDqXig0M+P35khNmbzBmOyzp3d
TmiYTS70o+kKF9JZ6kBOMlUltyc1RUSOxJfz0LodCpEiRsPHl51iJuhLYDAaI0qx
qrMapEfPF1svaLt2phumoNuUz2T1QotjK7jJAGGR1Uh/03TGxRrKaXaklNQZPNMe
mfKwNkcXmcBEf4a3qX683oQTrSm7I0kPXkxPzfUyr6GkV2Jz7BZSdExkPwyCoQ3e
IVgVwzznCmUcy2NMrg/qh/vA3VolCkkpxRFs5ZCbdErBvGo/WdUxD2YPStTVgbIm
3u2hV5Qrjzlos8a+8SJwS1iE0z89AgMBAAGjWTBXMA4GA1UdDwEB/wQEAwICpDAP
BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSNtoVJZwruHs/lvyCWprCZyRY8zzAV
BgNVHREEDjAMggprdWJlcm5ldGVzMA0GCSqGSIb3DQEBCwUAA4IBAQCXV3fxsdGS
wYxPsrdg8OJyTXlbZXrTElZwlY2yduWCFncj5uhpDjYYrtsY4t6A5KY2gDDQXFWi
w/mztClRkPQxCUbvEQrPzoCoYiN5xKoOxTqUNjOM8rcY6MG7UXET8nmMWYBG46Et
sWujq/kvPSIcJjY5estziEweV07W777HHcnZ2XU4x4IT3riXJkYlpH3UueJfjZ8/
hXWBfzbTC2/3BD0YO/AWWZq3w3itvaxt1kMhgKl3ZJqeI2fB3rq2fIcNbQ0tAoeh
DdCd3keX8/LwdId+2Z4zSrQAPT7akAJ5rAgLJSKUeHkJ33bpDPoQFVabI6UVfmaY
hb53Ic8Pu4SP
-----END CERTIFICATE-----
```
```bash
openssl x509 -in ca.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 5469543304450503442 (0x4be7b8a811637312)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 15 19:09:09 2035 GMT
        Subject: CN = kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d7:99:92:a1:a5:d3:43:48:4e:59:39:14:12:36:
                    96:3d:f3:73:0b:75:15:58:0c:d5:c3:a9:78:a0:d0:
                    cf:8f:df:99:21:36:66:f3:06:63:b2:ce:9d:dd:4e:
                    68:98:4d:2e:f4:a3:e9:0a:17:d2:59:ea:40:4e:32:
                    55:25:b7:27:35:45:44:8e:c4:97:f3:d0:ba:1d:0a:
                    91:22:46:c3:c7:97:9d:62:26:e8:4b:60:30:1a:23:
                    4a:b1:aa:b3:1a:a4:47:cf:17:5b:2f:68:bb:76:a6:
                    1b:a6:a0:db:94:cf:64:f5:42:8b:63:2b:b8:c9:00:
                    61:91:d5:48:7f:d3:74:c6:c5:1a:ca:69:76:a4:94:
                    d4:19:3c:d3:1e:99:f2:b0:36:47:17:99:c0:44:7f:
                    86:b7:a9:7e:bc:de:84:13:ad:29:bb:23:49:0f:5e:
                    4c:4f:cd:f5:32:af:a1:a4:57:62:73:ec:16:52:74:
                    4c:64:3f:0c:82:a1:0d:de:21:58:15:c3:3c:e7:0a:
                    65:1c:cb:63:4c:ae:0f:ea:87:fb:c0:dd:5a:25:0a:
                    49:29:c5:11:6c:e5:90:9b:74:4a:c1:bc:6a:3f:59:
                    d5:31:0f:66:0f:4a:d4:d5:81:b2:26:de:ed:a1:57:
                    94:2b:8f:39:68:b3:c6:be:f1:22:70:4b:58:84:d3:
                    3f:3d
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
            X509v3 Subject Alternative Name: 
                DNS:kubernetes
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        97:57:77:f1:b1:d1:92:c1:8c:4f:b2:b7:60:f0:e2:72:4d:79:
        5b:65:7a:d3:12:56:70:95:8d:b2:76:e5:82:16:77:23:e6:e8:
        69:0e:36:18:ae:db:18:e2:de:80:e4:a6:36:80:30:d0:5c:55:
        a2:c3:f9:b3:b4:29:51:90:f4:31:09:46:ef:11:0a:cf:ce:80:
        a8:62:23:79:c4:aa:0e:c5:3a:94:36:33:8c:f2:b7:18:e8:c1:
        bb:51:71:13:f2:79:8c:59:80:46:e3:a1:2d:b1:6b:a3:ab:f9:
        2f:3d:22:1c:26:36:39:7a:cb:73:88:4c:1e:57:4e:d6:ef:be:
        c7:1d:c9:d9:d9:75:38:c7:82:13:de:b8:97:26:46:25:a4:7d:
        d4:b9:e2:5f:8d:9f:3f:85:75:81:7f:36:d3:0b:6f:f7:04:3d:
        18:3b:f0:16:59:9a:b7:c3:78:ad:bd:ac:6d:d6:43:21:80:a9:
        77:64:9a:9e:23:67:c1:de:ba:b6:7c:87:0d:6d:0d:2d:02:87:
        a1:0d:d0:9d:de:47:97:f3:f2:f0:74:87:7e:d9:9e:33:4a:b4:
        00:3d:3e:da:90:02:79:ac:08:0b:25:22:94:78:79:09:df:76:
        e9:0c:fa:10:15:56:9b:23:a5:15:7e:66:98:85:be:77:21:cf:
        0f:bb:84:8f
```
```bash
kubectl config view --raw --kubeconfig=/etc/kubernetes/controller-manager.conf -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d > cm-client.crt
```
```bash
cat cm-client.crt 

-----BEGIN CERTIFICATE-----
MIIDFjCCAf6gAwIBAgIIJU7fnLA3j08wDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yNTExMTcxOTA0MDlaFw0yNjExMTcxOTA5MDlaMCkx
JzAlBgNVBAMTHnN5c3RlbTprdWJlLWNvbnRyb2xsZXItbWFuYWdlcjCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBAPBMp78FS/1xE9TrW4/ICoJXnmcrtl4t
rfW1eXg2+BReU1nrW3clC9+xRRN8Q3JlET2ouH89NZsWMvSDdSxGMaLgtvE3AU0C
TR+duNfbrfLm2JxyV6lJaMbLvyTpcuonXolSQPOaaRWhr6IvPwovciEOBGP77Uy7
3vA71v22TYoC9ieqhIGqVE4lxLDfQ+WWv3XzMSOarvbASdhOXQC2SL57cU1uGmZ/
k6XZJgOLMxNfvFO43Lz3AijT2OH1qxNkYBacw7sBpkyMmgS7c4+R7J3MD10nzl8H
dKxKOsmHyNac28/q1LFYlHrp7FY7U9YQJka6oQH6RTBXfHQIMwHjP/cCAwEAAaNW
MFQwDgYDVR0PAQH/BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMCMAwGA1UdEwEB
/wQCMAAwHwYDVR0jBBgwFoAUjbaFSWcK7h7P5b8glqawmckWPM8wDQYJKoZIhvcN
AQELBQADggEBAC79KLgStUya4Yate/Mck8CAWm+xhqXMg2RdDvar+SlPJSmuTjqm
bT1E1VSk/jkA9vbsPBkrXhtkvz6v5dNW+PfwLJ/VNpb0iZXqaSqkNVgRdPmNSL+M
AdrAyw2MOvlHNfA72UgSIywvvZ5zrvI3E3C0MXUDH2wR+52cWcGpIo2KgmAP1/SB
yctFiMTvgwKr26+OuV8YqylIXsJdMqQ+Pw3ZlSEWwYsw7t9o4pXaGxo3FmJ4ZHo7
WglIpop5iZIQ8t+nkpcQJBHNGmU7BNW2mb3kEkhenkU9iJeMjyX1MuBk98g9X5PG
BQksYm9/m6kG1Jl0jC/8mjBIruVVEqSZwgM=
-----END CERTIFICATE-----
```
```bash
openssl x509 -in cm-client.crt -text -noout

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 2688331891651088207 (0x254edf9cb0378f4f)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 17 19:09:09 2026 GMT
        Subject: CN = system:kube-controller-manager
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:f0:4c:a7:bf:05:4b:fd:71:13:d4:eb:5b:8f:c8:
                    0a:82:57:9e:67:2b:b6:5e:2d:ad:f5:b5:79:78:36:
                    f8:14:5e:53:59:eb:5b:77:25:0b:df:b1:45:13:7c:
                    43:72:65:11:3d:a8:b8:7f:3d:35:9b:16:32:f4:83:
                    75:2c:46:31:a2:e0:b6:f1:37:01:4d:02:4d:1f:9d:
                    b8:d7:db:ad:f2:e6:d8:9c:72:57:a9:49:68:c6:cb:
                    bf:24:e9:72:ea:27:5e:89:52:40:f3:9a:69:15:a1:
                    af:a2:2f:3f:0a:2f:72:21:0e:04:63:fb:ed:4c:bb:
                    de:f0:3b:d6:fd:b6:4d:8a:02:f6:27:aa:84:81:aa:
                    54:4e:25:c4:b0:df:43:e5:96:bf:75:f3:31:23:9a:
                    ae:f6:c0:49:d8:4e:5d:00:b6:48:be:7b:71:4d:6e:
                    1a:66:7f:93:a5:d9:26:03:8b:33:13:5f:bc:53:b8:
                    dc:bc:f7:02:28:d3:d8:e1:f5:ab:13:64:60:16:9c:
                    c3:bb:01:a6:4c:8c:9a:04:bb:73:8f:91:ec:9d:cc:
                    0f:5d:27:ce:5f:07:74:ac:4a:3a:c9:87:c8:d6:9c:
                    db:cf:ea:d4:b1:58:94:7a:e9:ec:56:3b:53:d6:10:
                    26:46:ba:a1:01:fa:45:30:57:7c:74:08:33:01:e3:
                    3f:f7
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        2e:fd:28:b8:12:b5:4c:9a:e1:86:ad:7b:f3:1c:93:c0:80:5a:
        6f:b1:86:a5:cc:83:64:5d:0e:f6:ab:f9:29:4f:25:29:ae:4e:
        3a:a6:6d:3d:44:d5:54:a4:fe:39:00:f6:f6:ec:3c:19:2b:5e:
        1b:64:bf:3e:af:e5:d3:56:f8:f7:f0:2c:9f:d5:36:96:f4:89:
        95:ea:69:2a:a4:35:58:11:74:f9:8d:48:bf:8c:01:da:c0:cb:
        0d:8c:3a:f9:47:35:f0:3b:d9:48:12:23:2c:2f:bd:9e:73:ae:
        f2:37:13:70:b4:31:75:03:1f:6c:11:fb:9d:9c:59:c1:a9:22:
        8d:8a:82:60:0f:d7:f4:81:c9:cb:45:88:c4:ef:83:02:ab:db:
        af:8e:b9:5f:18:ab:29:48:5e:c2:5d:32:a4:3e:3f:0d:d9:95:
        21:16:c1:8b:30:ee:df:68:e2:95:da:1b:1a:37:16:62:78:64:
        7a:3b:5a:09:48:a6:8a:79:89:92:10:f2:df:a7:92:97:10:24:
        11:cd:1a:65:3b:04:d5:b6:99:bd:e4:12:48:5e:9e:45:3d:88:
        97:8c:8f:25:f5:32:e0:64:f7:c8:3d:5f:93:c6:05:09:2c:62:
        6f:7f:9b:a9:06:d4:99:74:8c:2f:fc:9a:30:48:ae:e5:55:12:
        a4:99:c2:03
```

---

####  Task 2: Kubelet (Client) → API Server (Server)

You already saw kubelet acting as a server — now reverse the flow.

* How does the **kubelet authenticate to the API Server**?
* Where is the client cert stored?
* How does the API server validate it?

Look for flags like `--kubeconfig` in the kubelet's launch config.

```bash
controlplane:~$ ps -ef | grep kubelet
root        1608       1  1 05:53 ?        00:00:05 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --pod-infra-container-image=registry.k8s.io/pause:3.10.1 --container-runtime-endpoint unix:///run/containerd/containerd.sock --cgroup-driver=systemd --eviction-hard imagefs.available<5%,memory.available<100Mi,nodefs.available<5% --fail-swap-on=false
root        1921    1705  2 05:53 ?        00:00:12 kube-apiserver --advertise-address=172.30.1.2 --allow-privileged=true --authorization-mode=Node,RBAC --client-ca-file=/etc/kubernetes/pki/ca.crt --enable-admission-plugins=NodeRestriction --enable-bootstrap-token-auth=true --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key --etcd-servers=https://127.0.0.1:2379 --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key --requestheader-allowed-names=front-proxy-client --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt --requestheader-extra-headers-prefix=X-Remote-Extra- --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --secure-port=6443 --service-account-issuer=https://kubernetes.default.svc.cluster.local --service-account-key-file=/etc/kubernetes/pki/sa.pub --service-account-signing-key-file=/etc/kubernetes/pki/sa.key --service-cluster-ip-range=10.96.0.0/12 --tls-cert-file=/etc/kubernetes/pki/apiserver.crt --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
root        7341    7210  0 06:00 pts/0    00:00:00 grep --color=auto kubelet

controlplane:~$ cat /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
cgroupDriver: systemd
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
cpuManagerReconcilePeriod: 0s
crashLoopBackOff: {}
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMaximumGCAge: 0s
imageMinimumGCAge: 0s
kind: KubeletConfiguration
logging:
  flushFrequency: 0
  options:
    json:
      infoBufferSize: "0"
    text:
      infoBufferSize: "0"
  verbosity: 0
memorySwap: {}
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s

controlplane:~$ ps -ef | grep kubelet | grep -i kubeconfig
root        1608       1  1 05:53 ?        00:00:06 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --pod-infra-container-image=registry.k8s.io/pause:3.10.1 --container-runtime-endpoint unix:///run/containerd/containerd.sock --cgroup-driver=systemd --eviction-hard imagefs.available<5%,memory.available<100Mi,nodefs.available<5% --fail-swap-on=false

controlplane:~$ cat /etc/kubernetes/kubelet.conf
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJUytlNHFCRmpjeEl3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TlRFeE1UY3hPVEEwTURsYUZ3MHpOVEV4TVRVeE9UQTVNRGxhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUURYbVpLaHBkTkRTRTVaT1JRU05wWTk4M01MZFJWWUROWERxWGlnME0rUDM1a2hObWJ6Qm1PeXpwM2QKVG1pWVRTNzBvK2tLRjlKWjZrQk9NbFVsdHljMVJVU094SmZ6MExvZENwRWlSc1BIbDUxaUp1aExZREFhSTBxeApxck1hcEVmUEYxc3ZhTHQycGh1bW9OdVV6MlQxUW90aks3akpBR0dSMVVoLzAzVEd4UnJLYVhha2xOUVpQTk1lCm1mS3dOa2NYbWNCRWY0YTNxWDY4M29RVHJTbTdJMGtQWGt4UHpmVXlyNkdrVjJKejdCWlNkRXhrUHd5Q29RM2UKSVZnVnd6em5DbVVjeTJOTXJnL3FoL3ZBM1ZvbENra3B4UkZzNVpDYmRFckJ2R28vV2RVeEQyWVBTdFRWZ2JJbQozdTJoVjVRcmp6bG9zOGErOFNKd1MxaUUwejg5QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTTnRvVkpad3J1SHMvbHZ5Q1dwckNaeVJZOHp6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1hWM2Z4c2RHUwp3WXhQc3JkZzhPSnlUWGxiWlhyVEVsWndsWTJ5ZHVXQ0ZuY2o1dWhwRGpZWXJ0c1k0dDZBNUtZMmdERFFYRldpCncvbXp0Q2xSa1BReENVYnZFUXJQem9Db1lpTjV4S29PeFRxVU5qT004cmNZNk1HN1VYRVQ4bm1NV1lCRzQ2RXQKc1d1anEva3ZQU0ljSmpZNWVzdHppRXdlVjA3Vzc3N0hIY25aMlhVNHg0SVQzcmlYSmtZbHBIM1V1ZUpmalo4LwpoWFdCZnpiVEMyLzNCRDBZTy9BV1dacTN3M2l0dmF4dDFrTWhnS2wzWkpxZUkyZkIzcnEyZkljTmJRMHRBb2VoCkRkQ2Qza2VYOC9Md2RJZCsyWjR6U3JRQVBUN2FrQUo1ckFnTEpTS1VlSGtKMzNicERQb1FGVmFiSTZVVmZtYVkKaGI1M0ljOFB1NFNQCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://172.30.1.2:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:node:controlplane
  name: system:node:controlplane@kubernetes
current-context: system:node:controlplane@kubernetes
kind: Config
users:
- name: system:node:controlplane
  user:
    client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
    client-key: /var/lib/kubelet/pki/kubelet-client-current.pem

controlplane:~$ kubectl config view --raw --kubeconfig=/etc/kubernetes/kubelet.conf -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > ca.crt

controlplane:~$ cat ca.crt 
-----BEGIN CERTIFICATE-----
MIIDBTCCAe2gAwIBAgIIS+e4qBFjcxIwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yNTExMTcxOTA0MDlaFw0zNTExMTUxOTA5MDlaMBUx
EzARBgNVBAMTCmt1YmVybmV0ZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQDXmZKhpdNDSE5ZORQSNpY983MLdRVYDNXDqXig0M+P35khNmbzBmOyzp3d
TmiYTS70o+kKF9JZ6kBOMlUltyc1RUSOxJfz0LodCpEiRsPHl51iJuhLYDAaI0qx
qrMapEfPF1svaLt2phumoNuUz2T1QotjK7jJAGGR1Uh/03TGxRrKaXaklNQZPNMe
mfKwNkcXmcBEf4a3qX683oQTrSm7I0kPXkxPzfUyr6GkV2Jz7BZSdExkPwyCoQ3e
IVgVwzznCmUcy2NMrg/qh/vA3VolCkkpxRFs5ZCbdErBvGo/WdUxD2YPStTVgbIm
3u2hV5Qrjzlos8a+8SJwS1iE0z89AgMBAAGjWTBXMA4GA1UdDwEB/wQEAwICpDAP
BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSNtoVJZwruHs/lvyCWprCZyRY8zzAV
BgNVHREEDjAMggprdWJlcm5ldGVzMA0GCSqGSIb3DQEBCwUAA4IBAQCXV3fxsdGS
wYxPsrdg8OJyTXlbZXrTElZwlY2yduWCFncj5uhpDjYYrtsY4t6A5KY2gDDQXFWi
w/mztClRkPQxCUbvEQrPzoCoYiN5xKoOxTqUNjOM8rcY6MG7UXET8nmMWYBG46Et
sWujq/kvPSIcJjY5estziEweV07W777HHcnZ2XU4x4IT3riXJkYlpH3UueJfjZ8/
hXWBfzbTC2/3BD0YO/AWWZq3w3itvaxt1kMhgKl3ZJqeI2fB3rq2fIcNbQ0tAoeh
DdCd3keX8/LwdId+2Z4zSrQAPT7akAJ5rAgLJSKUeHkJ33bpDPoQFVabI6UVfmaY
hb53Ic8Pu4SP
-----END CERTIFICATE-----

controlplane:~$ openssl x509 -in ca.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 5469543304450503442 (0x4be7b8a811637312)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 15 19:09:09 2035 GMT
        Subject: CN = kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d7:99:92:a1:a5:d3:43:48:4e:59:39:14:12:36:
                    96:3d:f3:73:0b:75:15:58:0c:d5:c3:a9:78:a0:d0:
                    cf:8f:df:99:21:36:66:f3:06:63:b2:ce:9d:dd:4e:
                    68:98:4d:2e:f4:a3:e9:0a:17:d2:59:ea:40:4e:32:
                    55:25:b7:27:35:45:44:8e:c4:97:f3:d0:ba:1d:0a:
                    91:22:46:c3:c7:97:9d:62:26:e8:4b:60:30:1a:23:
                    4a:b1:aa:b3:1a:a4:47:cf:17:5b:2f:68:bb:76:a6:
                    1b:a6:a0:db:94:cf:64:f5:42:8b:63:2b:b8:c9:00:
                    61:91:d5:48:7f:d3:74:c6:c5:1a:ca:69:76:a4:94:
                    d4:19:3c:d3:1e:99:f2:b0:36:47:17:99:c0:44:7f:
                    86:b7:a9:7e:bc:de:84:13:ad:29:bb:23:49:0f:5e:
                    4c:4f:cd:f5:32:af:a1:a4:57:62:73:ec:16:52:74:
                    4c:64:3f:0c:82:a1:0d:de:21:58:15:c3:3c:e7:0a:
                    65:1c:cb:63:4c:ae:0f:ea:87:fb:c0:dd:5a:25:0a:
                    49:29:c5:11:6c:e5:90:9b:74:4a:c1:bc:6a:3f:59:
                    d5:31:0f:66:0f:4a:d4:d5:81:b2:26:de:ed:a1:57:
                    94:2b:8f:39:68:b3:c6:be:f1:22:70:4b:58:84:d3:
                    3f:3d
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
            X509v3 Subject Alternative Name: 
                DNS:kubernetes
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        97:57:77:f1:b1:d1:92:c1:8c:4f:b2:b7:60:f0:e2:72:4d:79:
        5b:65:7a:d3:12:56:70:95:8d:b2:76:e5:82:16:77:23:e6:e8:
        69:0e:36:18:ae:db:18:e2:de:80:e4:a6:36:80:30:d0:5c:55:
        a2:c3:f9:b3:b4:29:51:90:f4:31:09:46:ef:11:0a:cf:ce:80:
        a8:62:23:79:c4:aa:0e:c5:3a:94:36:33:8c:f2:b7:18:e8:c1:
        bb:51:71:13:f2:79:8c:59:80:46:e3:a1:2d:b1:6b:a3:ab:f9:
        2f:3d:22:1c:26:36:39:7a:cb:73:88:4c:1e:57:4e:d6:ef:be:
        c7:1d:c9:d9:d9:75:38:c7:82:13:de:b8:97:26:46:25:a4:7d:
        d4:b9:e2:5f:8d:9f:3f:85:75:81:7f:36:d3:0b:6f:f7:04:3d:
        18:3b:f0:16:59:9a:b7:c3:78:ad:bd:ac:6d:d6:43:21:80:a9:
        77:64:9a:9e:23:67:c1:de:ba:b6:7c:87:0d:6d:0d:2d:02:87:
        a1:0d:d0:9d:de:47:97:f3:f2:f0:74:87:7e:d9:9e:33:4a:b4:
        00:3d:3e:da:90:02:79:ac:08:0b:25:22:94:78:79:09:df:76:
        e9:0c:fa:10:15:56:9b:23:a5:15:7e:66:98:85:be:77:21:cf:
        0f:bb:84:8f

controlplane:~$ kubectl config view --raw --kubeconfig=/etc/kubernetes/kubelet.conf
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJUytlNHFCRmpjeEl3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TlRFeE1UY3hPVEEwTURsYUZ3MHpOVEV4TVRVeE9UQTVNRGxhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUURYbVpLaHBkTkRTRTVaT1JRU05wWTk4M01MZFJWWUROWERxWGlnME0rUDM1a2hObWJ6Qm1PeXpwM2QKVG1pWVRTNzBvK2tLRjlKWjZrQk9NbFVsdHljMVJVU094SmZ6MExvZENwRWlSc1BIbDUxaUp1aExZREFhSTBxeApxck1hcEVmUEYxc3ZhTHQycGh1bW9OdVV6MlQxUW90aks3akpBR0dSMVVoLzAzVEd4UnJLYVhha2xOUVpQTk1lCm1mS3dOa2NYbWNCRWY0YTNxWDY4M29RVHJTbTdJMGtQWGt4UHpmVXlyNkdrVjJKejdCWlNkRXhrUHd5Q29RM2UKSVZnVnd6em5DbVVjeTJOTXJnL3FoL3ZBM1ZvbENra3B4UkZzNVpDYmRFckJ2R28vV2RVeEQyWVBTdFRWZ2JJbQozdTJoVjVRcmp6bG9zOGErOFNKd1MxaUUwejg5QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTTnRvVkpad3J1SHMvbHZ5Q1dwckNaeVJZOHp6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1hWM2Z4c2RHUwp3WXhQc3JkZzhPSnlUWGxiWlhyVEVsWndsWTJ5ZHVXQ0ZuY2o1dWhwRGpZWXJ0c1k0dDZBNUtZMmdERFFYRldpCncvbXp0Q2xSa1BReENVYnZFUXJQem9Db1lpTjV4S29PeFRxVU5qT004cmNZNk1HN1VYRVQ4bm1NV1lCRzQ2RXQKc1d1anEva3ZQU0ljSmpZNWVzdHppRXdlVjA3Vzc3N0hIY25aMlhVNHg0SVQzcmlYSmtZbHBIM1V1ZUpmalo4LwpoWFdCZnpiVEMyLzNCRDBZTy9BV1dacTN3M2l0dmF4dDFrTWhnS2wzWkpxZUkyZkIzcnEyZkljTmJRMHRBb2VoCkRkQ2Qza2VYOC9Md2RJZCsyWjR6U3JRQVBUN2FrQUo1ckFnTEpTS1VlSGtKMzNicERQb1FGVmFiSTZVVmZtYVkKaGI1M0ljOFB1NFNQCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://172.30.1.2:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:node:controlplane
  name: system:node:controlplane@kubernetes
current-context: system:node:controlplane@kubernetes
kind: Config
users:
- name: system:node:controlplane
  user:
    client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
    client-key: /var/lib/kubelet/pki/kubelet-client-current.pem

controlplane:~$ ps -ef | grep kubelet | grep -i -E 'kubelet-client-key|kubelet-client-certificate'
root        1921    1705  2 05:53 ?        00:00:27 kube-apiserver --advertise-address=172.30.1.2 --allow-privileged=true --authorization-mode=Node,RBAC --client-ca-file=/etc/kubernetes/pki/ca.crt --enable-admission-plugins=NodeRestriction --enable-bootstrap-token-auth=true --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key --etcd-servers=https://127.0.0.1:2379 --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key --requestheader-allowed-names=front-proxy-client --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt --requestheader-extra-headers-prefix=X-Remote-Extra- --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --secure-port=6443 --service-account-issuer=https://kubernetes.default.svc.cluster.local --service-account-key-file=/etc/kubernetes/pki/sa.pub --service-account-signing-key-file=/etc/kubernetes/pki/sa.key --service-cluster-ip-range=10.96.0.0/12 --tls-cert-file=/etc/kubernetes/pki/apiserver.crt --tls-private-key-file=/etc/kubernetes/pki/apiserver.key

controlplane:~$ openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 4326103049491710733 (0x3c0967cd86b0030d)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 17 19:09:09 2026 GMT
        Subject: O = system:nodes, CN = system:node:controlplane
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c4:3e:f6:fd:97:a5:be:eb:70:bc:e1:2f:01:df:
                    1d:47:72:13:83:59:7e:b6:44:c3:38:b4:02:08:b1:
                    d2:c4:17:50:9a:41:b8:fd:63:2f:29:f6:75:66:96:
                    28:d1:5d:70:7b:63:1c:b5:fc:f0:e1:a0:8a:54:db:
                    8d:30:24:c2:06:a3:d5:c8:68:23:92:5e:e5:f2:0f:
                    eb:62:7e:12:a2:7e:4e:08:5c:2c:ec:e9:0f:c8:fa:
                    ad:87:b0:d7:6c:55:a9:63:af:48:07:46:69:25:e8:
                    77:3a:01:7e:6d:a7:46:d6:99:80:dc:b2:d2:be:0c:
                    b4:af:21:3c:95:60:e5:15:c7:fd:0f:84:e5:6c:2e:
                    f8:ce:24:9a:f3:fd:c5:9f:a6:89:a4:12:8e:97:17:
                    41:07:ff:0e:50:a1:3f:64:00:9d:27:50:d9:b9:dc:
                    e7:c1:38:66:c4:0e:b1:13:26:0b:c0:6f:8b:25:2f:
                    7c:19:e9:02:cf:f2:0e:82:5e:46:45:e5:55:b1:6f:
                    89:ee:0f:3c:a1:a9:fe:f7:d6:2d:d8:da:a3:a4:6b:
                    67:d9:15:da:a7:00:0a:b9:c1:a0:92:84:df:ab:c4:
                    b7:75:84:e2:6e:29:2c:cb:7c:e5:b9:1e:d2:39:a9:
                    08:a4:01:4e:10:1d:f0:a5:64:a7:d1:4d:13:29:18:
                    6e:db
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        c4:3a:fb:1a:f0:19:16:1a:b5:73:37:5a:7e:80:63:8d:f6:a3:
        3d:1e:e8:3b:78:f8:52:87:0a:65:e2:99:6a:f6:1a:0a:86:4c:
        9b:b7:37:cb:40:41:b2:9f:92:7c:58:33:92:4f:be:a5:12:01:
        d2:f6:bd:a9:a8:d8:27:a7:7e:2f:4f:05:93:a7:f4:6f:50:66:
        f4:09:7e:7a:8f:d7:2f:fa:69:b3:76:1b:60:0f:d0:46:f9:30:
        55:8d:b1:a7:aa:e1:3e:9e:70:7a:09:db:a5:53:f6:c0:29:c2:
        e3:93:eb:48:1c:e8:38:b9:83:e2:4c:db:f0:89:41:ff:f9:8d:
        47:7a:6d:9b:0d:3b:a5:1e:6e:d6:eb:b1:31:cf:d7:8c:c8:43:
        3e:f2:3a:3c:b2:05:9e:55:81:eb:1d:0a:6b:84:2d:b2:ba:cc:
        2d:88:db:b2:c3:26:11:c8:e3:89:7d:c3:8b:e4:54:34:01:21:
        84:20:48:c2:d1:23:63:4a:c6:2b:f6:e1:57:c0:74:55:f3:17:
        d9:0f:63:be:dc:a8:f5:5e:32:08:7c:3a:0e:2b:ea:db:37:f9:
        2d:2c:2d:95:82:2e:3b:63:f3:cc:28:7e:9f:76:de:da:dc:e3:
        1e:e4:5f:48:33:05:41:fe:bf:1a:0f:ba:c3:d6:01:8c:6d:2d:
        f1:67:8e:4e

controlplane:~$ cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -m1 client-ca-file
    - --client-ca-file=/etc/kubernetes/pki/ca.crt

```

---

####  Task 3: Kube-Proxy (Client) → API Server (Server)

This one’s a bit more involved — kube-proxy runs as a **DaemonSet**.

* SSH into a node or use `kubectl exec`  to explore a **kube-proxy pod**.
* Find its **kubeconfig file**.
* Inspect the client certificate it uses.
* Confirm how the **API server authenticates** this client.

 **Challenge**: For this task, you'll need to **research on your own**. Use official Kubernetes docs, GitHub, or community threads. This is an essential skill when dealing with real-world clusters.

```bash
controlplane:~$ cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep tls   
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key

controlplane:~$ kubectl get pods -n kube-system -owide| grep kube-proxy
kube-proxy-cf4m9                          1/1     Running   1 (26m ago)   5d10h   172.30.2.2    node01         <none>           <none>
kube-proxy-k5v4v                          1/1     Running   2 (26m ago)   5d11h   172.30.1.2    controlplane   <none>           <none>

controlplane:~$ kubectl get pod kube-proxy-k5v4v -n kube-system -oyaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2025-11-17T19:09:40Z"
  generateName: kube-proxy-
  generation: 1
  labels:
    controller-revision-hash: 66486579fc
    k8s-app: kube-proxy
    pod-template-generation: "1"
  name: kube-proxy-k5v4v
  namespace: kube-system
  ownerReferences:
  - apiVersion: apps/v1
    blockOwnerDeletion: true
    controller: true
    kind: DaemonSet
    name: kube-proxy
    uid: cb60b2d6-24b9-411d-925f-c479e385bd4e
  resourceVersion: "2579"
  uid: c674b767-5a51-45bc-b5b6-6ce26eb6dc74
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchFields:
          - key: metadata.name
            operator: In
            values:
            - controlplane
  containers:
  - command:
    - /usr/local/bin/kube-proxy
    - --config=/var/lib/kube-proxy/config.conf
    - --hostname-override=$(NODE_NAME)
    env:
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: spec.nodeName
    image: registry.k8s.io/kube-proxy:v1.34.1
    imagePullPolicy: IfNotPresent
    name: kube-proxy
    resources: {}
    securityContext:
      privileged: true
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/lib/kube-proxy
      name: kube-proxy
    - mountPath: /run/xtables.lock
      name: xtables-lock
    - mountPath: /lib/modules
      name: lib-modules
      readOnly: true
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-nn5wk
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  hostNetwork: true
  nodeName: controlplane
  nodeSelector:
    kubernetes.io/os: linux
  preemptionPolicy: PreemptLowerPriority
  priority: 2000001000
  priorityClassName: system-node-critical
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext: {}
  serviceAccount: kube-proxy
  serviceAccountName: kube-proxy
  terminationGracePeriodSeconds: 30
  tolerations:
  - operator: Exists
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
  - effect: NoSchedule
    key: node.kubernetes.io/disk-pressure
    operator: Exists
  - effect: NoSchedule
    key: node.kubernetes.io/memory-pressure
    operator: Exists
  - effect: NoSchedule
    key: node.kubernetes.io/pid-pressure
    operator: Exists
  - effect: NoSchedule
    key: node.kubernetes.io/unschedulable
    operator: Exists
  - effect: NoSchedule
    key: node.kubernetes.io/network-unavailable
    operator: Exists
  volumes:
  - configMap:
      defaultMode: 420
      name: kube-proxy
    name: kube-proxy
  - hostPath:
      path: /run/xtables.lock
      type: FileOrCreate
    name: xtables-lock
  - hostPath:
      path: /lib/modules
      type: ""
    name: lib-modules
  - name: kube-api-access-nn5wk
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
status:
  conditions:
  - lastProbeTime: null
    lastTransitionTime: "2025-11-23T05:53:35Z"
    observedGeneration: 1
    status: "True"
    type: PodReadyToStartContainers
  - lastProbeTime: null
    lastTransitionTime: "2025-11-17T19:09:40Z"
    observedGeneration: 1
    status: "True"
    type: Initialized
  - lastProbeTime: null
    lastTransitionTime: "2025-11-23T05:53:35Z"
    observedGeneration: 1
    status: "True"
    type: Ready
  - lastProbeTime: null
    lastTransitionTime: "2025-11-23T05:53:35Z"
    observedGeneration: 1
    status: "True"
    type: ContainersReady
  - lastProbeTime: null
    lastTransitionTime: "2025-11-17T19:09:40Z"
    observedGeneration: 1
    status: "True"
    type: PodScheduled
  containerStatuses:
  - containerID: containerd://c28f26670749f093b7ffa803f45650d67956e94307b7868bf0f3e188464d3e99
    image: registry.k8s.io/kube-proxy:v1.34.1
    imageID: registry.k8s.io/kube-proxy@sha256:913cc83ca0b5588a81d86ce8eedeb3ed1e9c1326e81852a1ea4f622b74ff749a
    lastState:
      terminated:
        containerID: containerd://e6497fd98dc141c0fa4a5a011f0abd431a1aa8660bb56226e9476aa40d0f635c
        exitCode: 255
        finishedAt: "2025-11-23T05:53:04Z"
        reason: Unknown
        startedAt: "2025-11-17T19:39:13Z"
    name: kube-proxy
    ready: true
    resources: {}
    restartCount: 2
    started: true
    state:
      running:
        startedAt: "2025-11-23T05:53:34Z"
    volumeMounts:
    - mountPath: /var/lib/kube-proxy
      name: kube-proxy
    - mountPath: /run/xtables.lock
      name: xtables-lock
    - mountPath: /lib/modules
      name: lib-modules
      readOnly: true
      recursiveReadOnly: Disabled
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-nn5wk
      readOnly: true
      recursiveReadOnly: Disabled
  hostIP: 172.30.1.2
  hostIPs:
  - ip: 172.30.1.2
  observedGeneration: 1
  phase: Running
  podIP: 172.30.1.2
  podIPs:
  - ip: 172.30.1.2
  qosClass: BestEffort
  startTime: "2025-11-17T19:09:40Z"

controlplane:~$ kubectl get configmap kube-proxy -n kube-system -oyaml
apiVersion: v1
data:
  config.conf: |-
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    bindAddress: 0.0.0.0
    bindAddressHardFail: false
    clientConnection:
      acceptContentTypes: ""
      burst: 0
      contentType: ""
      kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
      qps: 0
    clusterCIDR: 192.168.0.0/16
    configSyncPeriod: 0s
    conntrack:
      maxPerCore: null
      min: null
      tcpBeLiberal: false
      tcpCloseWaitTimeout: null
      tcpEstablishedTimeout: null
      udpStreamTimeout: 0s
      udpTimeout: 0s
    detectLocal:
      bridgeInterface: ""
      interfaceNamePrefix: ""
    detectLocalMode: ""
    enableProfiling: false
    healthzBindAddress: ""
    hostnameOverride: ""
    iptables:
      localhostNodePorts: null
      masqueradeAll: false
      masqueradeBit: null
      minSyncPeriod: 0s
      syncPeriod: 0s
    ipvs:
      excludeCIDRs: null
      minSyncPeriod: 0s
      scheduler: ""
      strictARP: false
      syncPeriod: 0s
      tcpFinTimeout: 0s
      tcpTimeout: 0s
      udpTimeout: 0s
    kind: KubeProxyConfiguration
    logging:
      flushFrequency: 0
      options:
        json:
          infoBufferSize: "0"
        text:
          infoBufferSize: "0"
      verbosity: 0
    metricsBindAddress: ""
    mode: ""
    nftables:
      masqueradeAll: false
      masqueradeBit: null
      minSyncPeriod: 0s
      syncPeriod: 0s
    nodePortAddresses: null
    oomScoreAdj: null
    portRange: ""
    showHiddenMetricsForVersion: ""
    winkernel:
      enableDSR: false
      forwardHealthCheckVip: false
      networkName: ""
      rootHnsEndpointName: ""
      sourceVip: ""
  kubeconfig.conf: |-
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        server: https://172.30.1.2:6443
      name: default
    contexts:
    - context:
        cluster: default
        namespace: default
        user: default
      name: default
    current-context: default
    users:
    - name: default
      user:
        tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
kind: ConfigMap
metadata:
  annotations:
    kubeadm.kubernetes.io/component-config.hash: sha256:ee893d852f163f709c3acc9815d2d986ba7e837e8cf4ca7c2aed8cb9aef6d972
  creationTimestamp: "2025-11-17T19:09:33Z"
  labels:
    app: kube-proxy
  name: kube-proxy
  namespace: kube-system
  resourceVersion: "274"
  uid: 0920f3ee-9a6d-473c-89eb-7c2b11fa444e

controlplane:~$ kubectl get configmap -n kube-system kube-root-ca.crt -oyaml
apiVersion: v1
data:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDBTCCAe2gAwIBAgIIS+e4qBFjcxIwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
    AxMKa3ViZXJuZXRlczAeFw0yNTExMTcxOTA0MDlaFw0zNTExMTUxOTA5MDlaMBUx
    EzARBgNVBAMTCmt1YmVybmV0ZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
    AoIBAQDXmZKhpdNDSE5ZORQSNpY983MLdRVYDNXDqXig0M+P35khNmbzBmOyzp3d
    TmiYTS70o+kKF9JZ6kBOMlUltyc1RUSOxJfz0LodCpEiRsPHl51iJuhLYDAaI0qx
    qrMapEfPF1svaLt2phumoNuUz2T1QotjK7jJAGGR1Uh/03TGxRrKaXaklNQZPNMe
    mfKwNkcXmcBEf4a3qX683oQTrSm7I0kPXkxPzfUyr6GkV2Jz7BZSdExkPwyCoQ3e
    IVgVwzznCmUcy2NMrg/qh/vA3VolCkkpxRFs5ZCbdErBvGo/WdUxD2YPStTVgbIm
    3u2hV5Qrjzlos8a+8SJwS1iE0z89AgMBAAGjWTBXMA4GA1UdDwEB/wQEAwICpDAP
    BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSNtoVJZwruHs/lvyCWprCZyRY8zzAV
    BgNVHREEDjAMggprdWJlcm5ldGVzMA0GCSqGSIb3DQEBCwUAA4IBAQCXV3fxsdGS
    wYxPsrdg8OJyTXlbZXrTElZwlY2yduWCFncj5uhpDjYYrtsY4t6A5KY2gDDQXFWi
    w/mztClRkPQxCUbvEQrPzoCoYiN5xKoOxTqUNjOM8rcY6MG7UXET8nmMWYBG46Et
    sWujq/kvPSIcJjY5estziEweV07W777HHcnZ2XU4x4IT3riXJkYlpH3UueJfjZ8/
    hXWBfzbTC2/3BD0YO/AWWZq3w3itvaxt1kMhgKl3ZJqeI2fB3rq2fIcNbQ0tAoeh
    DdCd3keX8/LwdId+2Z4zSrQAPT7akAJ5rAgLJSKUeHkJ33bpDPoQFVabI6UVfmaY
    hb53Ic8Pu4SP
    -----END CERTIFICATE-----
kind: ConfigMap
metadata:
  annotations:
    kubernetes.io/description: Contains a CA bundle that can be used to verify the
      kube-apiserver when using internal endpoints such as the internal service IP
      or kubernetes.default.svc. No other usage is guaranteed across distributions
      of Kubernetes clusters.
  creationTimestamp: "2025-11-17T19:09:40Z"
  name: kube-root-ca.crt
  namespace: kube-system
  resourceVersion: "418"
  uid: 15f47ff6-13b3-4742-af2c-12a093b1a70f


controlplane:~$ kubectl get configmap kube-root-ca.crt -n kube-system   -o jsonpath='{.data.ca\.crt}' > ca.crt

controlplane:~$ openssl x509 -in ca.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 5469543304450503442 (0x4be7b8a811637312)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 15 19:09:09 2035 GMT
        Subject: CN = kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d7:99:92:a1:a5:d3:43:48:4e:59:39:14:12:36:
                    96:3d:f3:73:0b:75:15:58:0c:d5:c3:a9:78:a0:d0:
                    cf:8f:df:99:21:36:66:f3:06:63:b2:ce:9d:dd:4e:
                    68:98:4d:2e:f4:a3:e9:0a:17:d2:59:ea:40:4e:32:
                    55:25:b7:27:35:45:44:8e:c4:97:f3:d0:ba:1d:0a:
                    91:22:46:c3:c7:97:9d:62:26:e8:4b:60:30:1a:23:
                    4a:b1:aa:b3:1a:a4:47:cf:17:5b:2f:68:bb:76:a6:
                    1b:a6:a0:db:94:cf:64:f5:42:8b:63:2b:b8:c9:00:
                    61:91:d5:48:7f:d3:74:c6:c5:1a:ca:69:76:a4:94:
                    d4:19:3c:d3:1e:99:f2:b0:36:47:17:99:c0:44:7f:
                    86:b7:a9:7e:bc:de:84:13:ad:29:bb:23:49:0f:5e:
                    4c:4f:cd:f5:32:af:a1:a4:57:62:73:ec:16:52:74:
                    4c:64:3f:0c:82:a1:0d:de:21:58:15:c3:3c:e7:0a:
                    65:1c:cb:63:4c:ae:0f:ea:87:fb:c0:dd:5a:25:0a:
                    49:29:c5:11:6c:e5:90:9b:74:4a:c1:bc:6a:3f:59:
                    d5:31:0f:66:0f:4a:d4:d5:81:b2:26:de:ed:a1:57:
                    94:2b:8f:39:68:b3:c6:be:f1:22:70:4b:58:84:d3:
                    3f:3d
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
            X509v3 Subject Alternative Name: 
                DNS:kubernetes
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        97:57:77:f1:b1:d1:92:c1:8c:4f:b2:b7:60:f0:e2:72:4d:79:
        5b:65:7a:d3:12:56:70:95:8d:b2:76:e5:82:16:77:23:e6:e8:
        69:0e:36:18:ae:db:18:e2:de:80:e4:a6:36:80:30:d0:5c:55:
        a2:c3:f9:b3:b4:29:51:90:f4:31:09:46:ef:11:0a:cf:ce:80:
        a8:62:23:79:c4:aa:0e:c5:3a:94:36:33:8c:f2:b7:18:e8:c1:
        bb:51:71:13:f2:79:8c:59:80:46:e3:a1:2d:b1:6b:a3:ab:f9:
        2f:3d:22:1c:26:36:39:7a:cb:73:88:4c:1e:57:4e:d6:ef:be:
        c7:1d:c9:d9:d9:75:38:c7:82:13:de:b8:97:26:46:25:a4:7d:
        d4:b9:e2:5f:8d:9f:3f:85:75:81:7f:36:d3:0b:6f:f7:04:3d:
        18:3b:f0:16:59:9a:b7:c3:78:ad:bd:ac:6d:d6:43:21:80:a9:
        77:64:9a:9e:23:67:c1:de:ba:b6:7c:87:0d:6d:0d:2d:02:87:
        a1:0d:d0:9d:de:47:97:f3:f2:f0:74:87:7e:d9:9e:33:4a:b4:
        00:3d:3e:da:90:02:79:ac:08:0b:25:22:94:78:79:09:df:76:
        e9:0c:fa:10:15:56:9b:23:a5:15:7e:66:98:85:be:77:21:cf:
        0f:bb:84:8f

controlplane:~$ kubectl exec -it kube-proxy-k5v4v -n kube-system -- cat /var/lib/kube-proxy/config.conf
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 0.0.0.0
bindAddressHardFail: false
clientConnection:
  acceptContentTypes: ""
  burst: 0
  contentType: ""
  kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
  qps: 0
clusterCIDR: 192.168.0.0/16
configSyncPeriod: 0s
conntrack:
  maxPerCore: null
  min: null
  tcpBeLiberal: false
  tcpCloseWaitTimeout: null
  tcpEstablishedTimeout: null
  udpStreamTimeout: 0s
  udpTimeout: 0s
detectLocal:
  bridgeInterface: ""
  interfaceNamePrefix: ""
detectLocalMode: ""
enableProfiling: false
healthzBindAddress: ""
hostnameOverride: ""
iptables:
  localhostNodePorts: null
  masqueradeAll: false
  masqueradeBit: null
  minSyncPeriod: 0s
  syncPeriod: 0s
ipvs:
  excludeCIDRs: null
  minSyncPeriod: 0s
  scheduler: ""
  strictARP: false
  syncPeriod: 0s
  tcpFinTimeout: 0s
  tcpTimeout: 0s
  udpTimeout: 0s
kind: KubeProxyConfiguration
logging:
  flushFrequency: 0
  options:
    json:
      infoBufferSize: "0"
    text:
      infoBufferSize: "0"
  verbosity: 0
metricsBindAddress: ""
mode: ""
nftables:
  masqueradeAll: false
  masqueradeBit: null
  minSyncPeriod: 0s
  syncPeriod: 0s
nodePortAddresses: null
oomScoreAdj: null
portRange: ""
showHiddenMetricsForVersion: ""
winkernel:
  enableDSR: false
  forwardHealthCheckVip: false
  networkName: ""
  rootHnsEndpointName: ""
  sourceVip: ""

controlplane:~$ kubectl exec -it kube-proxy-k5v4v -n kube-system -- cat /var/lib/kube-proxy/kubeconfig.conf
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    server: https://172.30.1.2:6443
  name: default
contexts:
- context:
    cluster: default
    namespace: default
    user: default
  name: default
current-context: default
users:
- name: default
  user:
    tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token

controlplane:~$ kubectl exec -it kube-proxy-k5v4v -n kube-system -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt > ca.crt

controlplane:~$ openssl x509 -in ca.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 5469543304450503442 (0x4be7b8a811637312)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Nov 17 19:04:09 2025 GMT
            Not After : Nov 15 19:09:09 2035 GMT
        Subject: CN = kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d7:99:92:a1:a5:d3:43:48:4e:59:39:14:12:36:
                    96:3d:f3:73:0b:75:15:58:0c:d5:c3:a9:78:a0:d0:
                    cf:8f:df:99:21:36:66:f3:06:63:b2:ce:9d:dd:4e:
                    68:98:4d:2e:f4:a3:e9:0a:17:d2:59:ea:40:4e:32:
                    55:25:b7:27:35:45:44:8e:c4:97:f3:d0:ba:1d:0a:
                    91:22:46:c3:c7:97:9d:62:26:e8:4b:60:30:1a:23:
                    4a:b1:aa:b3:1a:a4:47:cf:17:5b:2f:68:bb:76:a6:
                    1b:a6:a0:db:94:cf:64:f5:42:8b:63:2b:b8:c9:00:
                    61:91:d5:48:7f:d3:74:c6:c5:1a:ca:69:76:a4:94:
                    d4:19:3c:d3:1e:99:f2:b0:36:47:17:99:c0:44:7f:
                    86:b7:a9:7e:bc:de:84:13:ad:29:bb:23:49:0f:5e:
                    4c:4f:cd:f5:32:af:a1:a4:57:62:73:ec:16:52:74:
                    4c:64:3f:0c:82:a1:0d:de:21:58:15:c3:3c:e7:0a:
                    65:1c:cb:63:4c:ae:0f:ea:87:fb:c0:dd:5a:25:0a:
                    49:29:c5:11:6c:e5:90:9b:74:4a:c1:bc:6a:3f:59:
                    d5:31:0f:66:0f:4a:d4:d5:81:b2:26:de:ed:a1:57:
                    94:2b:8f:39:68:b3:c6:be:f1:22:70:4b:58:84:d3:
                    3f:3d
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                8D:B6:85:49:67:0A:EE:1E:CF:E5:BF:20:96:A6:B0:99:C9:16:3C:CF
            X509v3 Subject Alternative Name: 
                DNS:kubernetes
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        97:57:77:f1:b1:d1:92:c1:8c:4f:b2:b7:60:f0:e2:72:4d:79:
        5b:65:7a:d3:12:56:70:95:8d:b2:76:e5:82:16:77:23:e6:e8:
        69:0e:36:18:ae:db:18:e2:de:80:e4:a6:36:80:30:d0:5c:55:
        a2:c3:f9:b3:b4:29:51:90:f4:31:09:46:ef:11:0a:cf:ce:80:
        a8:62:23:79:c4:aa:0e:c5:3a:94:36:33:8c:f2:b7:18:e8:c1:
        bb:51:71:13:f2:79:8c:59:80:46:e3:a1:2d:b1:6b:a3:ab:f9:
        2f:3d:22:1c:26:36:39:7a:cb:73:88:4c:1e:57:4e:d6:ef:be:
        c7:1d:c9:d9:d9:75:38:c7:82:13:de:b8:97:26:46:25:a4:7d:
        d4:b9:e2:5f:8d:9f:3f:85:75:81:7f:36:d3:0b:6f:f7:04:3d:
        18:3b:f0:16:59:9a:b7:c3:78:ad:bd:ac:6d:d6:43:21:80:a9:
        77:64:9a:9e:23:67:c1:de:ba:b6:7c:87:0d:6d:0d:2d:02:87:
        a1:0d:d0:9d:de:47:97:f3:f2:f0:74:87:7e:d9:9e:33:4a:b4:
        00:3d:3e:da:90:02:79:ac:08:0b:25:22:94:78:79:09:df:76:
        e9:0c:fa:10:15:56:9b:23:a5:15:7e:66:98:85:be:77:21:cf:
        0f:bb:84:8f



```

---


## Conclusion

In this lecture, you learned how **Kubernetes uses TLS and private CAs** to secure internal communication:

* You saw how each component acts as a **client or server** in different scenarios.
* You explored how **certificates are issued, validated, and trusted** — often asymmetrically.
* And you saw how **TLS bootstrapping and client auth** work without needing to memorize paths.

This understanding sets the stage for the final part of the series — where we’ll complete the picture with **TLS at the etcd layer**, and how to fully secure your Kubernetes control plane.

---

Excellent — this transcript is from a **deep-dive on TLS certificate chains** and it directly connects to how **Kubernetes and browsers trust certificates**. Let’s summarize and map out the **flow** you’re referring to — from *self-signed root CA → intermediate CA → leaf certificate → client verification (like kubectl or browser)*.

Here’s the **flow explained clearly** 👇

---

## 🧩 **1. Self-Signed Certificate (Root CA)**

* A **Root Certificate Authority (Root CA)** is the *topmost* authority in a trust chain.
* It **signs its own certificate** — meaning:

  ```
  Root Certificate = Signed by Root’s own Private Key
  ```
* Because it’s **self-signed**, browsers and operating systems **must manually trust** this certificate — that’s why it’s pre-installed in the browser or OS “trusted root store.”

✅ **Stored in browser/OS root trust store**
❌ **Never used to directly sign client certificates frequently** (for safety)

---

## **2. Intermediate CA**

* The Root CA **creates and signs** one or more **Intermediate CA certificates**.
* These intermediates handle **day-to-day signing** of website or service certificates (like `github.com`, `pinkbank.com`, etc.)
* Why?

  * Reduces risk — Root CA private key is never exposed or online.
  * If an intermediate is compromised, only that one can be revoked, not the whole ecosystem.

✅ Root CA signs → Intermediate CA
✅ Intermediate CA signs → Leaf certificate (your website/service)

---

## **3. Leaf Certificate (End-Entity Certificate)**

* This is the certificate used by:

  * Websites (`github.com`, `google.com`)
  * Kubernetes API servers
  * Application endpoints
* It’s issued (signed) by the **Intermediate CA’s private key**.

Example:

```
pinkbank.com cert ← signed by Let's Encrypt Intermediate CA
Let's Encrypt Intermediate CA cert ← signed by Let's Encrypt Root CA
Let's Encrypt Root CA cert ← self-signed
```

---

## **4. The Chain of Trust**

When you connect to `https://pinkbank.com`, the **server sends**:

```
[Leaf Cert: pinkbank.com]
[Intermediate CA Cert: Let's Encrypt Intermediate]
```

Your **browser or kubectl** already has the **Root CA certificate** locally (in its trust store).

Now the browser does this:

1. Verify the leaf cert’s signature using Intermediate CA’s public key.
2. Verify the Intermediate CA cert’s signature using Root CA’s public key.
3. Verify the Root CA cert is trusted (exists in local trust store).
4. ✅ If all valid → “Chain of Trust Complete.”

---

## **5. Why Use a Root + Intermediate Structure**

| Problem                          | Solution                                                  |
| -------------------------------- | --------------------------------------------------------- |
| Root CA private key too valuable | Keep it offline, use intermediates for daily work         |
| Risk of key compromise           | Only intermediate key gets exposed                        |
| Flexibility                      | Different intermediates for different policies or regions |
| Scalability                      | Easier certificate revocation and rotation                |

---

## **6. Storage and Security of Keys**

| Type                         | Key Location                               | Usage                                            |
| ---------------------------- | ------------------------------------------ | ------------------------------------------------ |
| Root CA Private Key          | Hardware Security Module (HSM), air-gapped | Used **only once** to sign Intermediate CA certs |
| Intermediate CA Private Key  | Secure online HSM                          | Used regularly to sign end-entity certificates   |
| Leaf Certificate Private Key | Web server / API server                    | Used for actual TLS handshakes                   |

---

## **7. Communication Flow (Verification Path)**

Here’s the flow when your browser or `kubectl` connects securely:

```
[Client]  → requests →  [Server/API]
                 ↓
       Server sends certificate chain:
       - Leaf certificate (service)
       - Intermediate CA certificate
                 ↓
Client verifies:
1️⃣ Intermediate CA signature ← Root CA
2️⃣ Leaf cert signature ← Intermediate CA
3️⃣ Root CA is trusted in system
                 ↓
✅ Connection trusted (mTLS if both sides present certs)
```

---

## **8. In Kubernetes Context**

In Kubernetes, this same flow happens for internal authentication:

* The **Kubernetes Root CA** (self-signed) is stored in `/etc/kubernetes/pki/ca.crt`.
* It signs:

  * The **API Server certificate**
  * **kubelet**, **controller-manager**, and **scheduler** certificates
* `kubectl` trusts this CA (from your `kubeconfig` file).

### Example:

```
Root CA (self-signed)
   ↓
Intermediate (optional)
   ↓
API Server Certificate
```

When scheduler connects to API Server:

1. Scheduler gets the API Server’s certificate.
2. Verifies it using the Root CA (from `/etc/kubernetes/pki/ca.crt`).
3. If the signature matches → scheduler trusts the API server.

---

## **In Summary: Certificate Trust Chain Flow**

```
 Root CA (self-signed, offline)
      ↓
 Intermediate CA (signed by Root)
      ↓
 Leaf Certificate (server cert, signed by Intermediate)
      ↓
 Browser / Client / kubectl
      ↓
 Verify each signature until reaching trusted Root
```

---

Would you like me to draw this **as a labeled diagram** (Root → Intermediate → Leaf → Browser Verification)?
It’ll show the **full certificate chain flow** visually like in the transcript — easy to remember and explain in interviews.

---

## References

* **Kubernetes TLS Overview** – TLS and certificates in Kubernetes
  [https://kubernetes.io/docs/concepts/cluster-administration/certificates/](https://kubernetes.io/docs/concepts/cluster-administration/certificates/)

* **Kubeconfig Explained** – Structure and usage of kubeconfig files
  [https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)

* **TLS Bootstrapping** – How kubelet requests client certificates
  [https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/)

---




