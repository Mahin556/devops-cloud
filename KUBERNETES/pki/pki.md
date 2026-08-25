Absolutely. If you are preparing for a **Kubernetes/DevOps interview**, you should understand the complete PKI structure—not just `kubelet-client-current.pem`.

Below is the **complete Kubernetes PKI architecture**, mainly for a **kubeadm-created cluster**.

Kubernetes uses PKI/TLS extensively for authentication and encrypted communication between components. With kubeadm, most control-plane PKI material is stored under `/etc/kubernetes/pki`. ([Kubernetes][1])

---

![alt text](image.png)

# 1. Kubernetes PKI — Big Picture

Think of Kubernetes PKI like this:

```text
                         Kubernetes PKI
                              |
          +-------------------+-------------------+
          |                   |                   |
       Kubernetes CA       etcd CA          Front Proxy CA
          |                   |                   |
    +-----+------+       +----+-----+        +----+------+
    |     |      |       |    |     |        |
    |     |      |       |    |     |        |
 API   Kubelet  Other   etcd etcd  API      Front
Server clients clients server peer client    Proxy
    |
    +--------------------------------------------------+
                       |
                  ServiceAccount
                  sa.key / sa.pub
                  (NOT X.509)
```

There are essentially **three major certificate authorities** in a standard kubeadm cluster:

```text
1. Kubernetes CA
2. etcd CA
3. Front-proxy CA
```

And there is also:

```text
4. ServiceAccount signing key pair
   sa.key
   sa.pub
```

The ServiceAccount key pair is **not an X.509 certificate/CA**; it is used for signing ServiceAccount tokens. ([Kubernetes][1])

---

# 2. Main PKI Directory

On a kubeadm control-plane node:

```bash
/etc/kubernetes/pki/
```

Typical structure:

```text
/etc/kubernetes/
│
├── admin.conf
├── controller-manager.conf
├── scheduler.conf
├── kubelet.conf
│
└── pki/
    │
    ├── ca.crt
    ├── ca.key
    │
    ├── apiserver.crt
    ├── apiserver.key
    │
    ├── apiserver-kubelet-client.crt
    ├── apiserver-kubelet-client.key
    │
    ├── front-proxy-ca.crt
    ├── front-proxy-ca.key
    ├── front-proxy-client.crt
    ├── front-proxy-client.key
    │
    ├── sa.key
    ├── sa.pub
    │
    └── etcd/
        ├── ca.crt
        ├── ca.key
        ├── server.crt
        ├── server.key
        ├── peer.crt
        ├── peer.key
        ├── healthcheck-client.crt
        ├── healthcheck-client.key
        ├── apiserver-etcd-client.crt
        └── apiserver-etcd-client.key
```

The exact set can vary depending on the deployment, especially with **external etcd** or external CA configurations. ([Kubernetes][1])

---

# 3. Kubernetes CA

The most important CA is:

```text
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
```

Think:

```text
              Kubernetes CA
             /             \
            /               \
       Certificate         Private Key
          ca.crt              ca.key
```

### `ca.crt`

Public CA certificate.

It can be distributed to components that need to **trust certificates signed by this CA**.

### `ca.key`

Extremely sensitive.

It is the **private key used to sign Kubernetes certificates**.

If someone gets:

```text
ca.key
```

they may be able to create certificates that Kubernetes trusts.

Therefore:

```text
ca.key  >>> VERY SENSITIVE
ca.crt  >>> public trust certificate
```

---

# 4. What does Kubernetes CA sign?

The Kubernetes CA is used for many Kubernetes component certificates.

Conceptually:

```text
                    Kubernetes CA
                         |
          +--------------+---------------+
          |              |               |
          ↓              ↓               ↓
    kube-apiserver   kubelet-client   controller/
       certs           certs          scheduler certs
```

Important examples:

```text
apiserver.crt
apiserver-kubelet-client.crt
kubelet client certificates
admin client certificates
controller-manager client certificate
scheduler client certificate
```

The Kubernetes documentation identifies certificates for API server, kubelets, controller-manager, scheduler and administrators as part of the Kubernetes PKI. ([Kubernetes][1])

---

# 5. API Server Certificate

Files:

```text
/etc/kubernetes/pki/apiserver.crt
/etc/kubernetes/pki/apiserver.key
```

This is the **server certificate of kube-apiserver**.

The communication looks like:

```text
kubectl
   |
   | HTTPS
   |
   ↓
kube-apiserver
   |
   | apiserver.crt
   | apiserver.key
```

The API server presents:

```text
apiserver.crt
```

to clients.

The private key:

```text
apiserver.key
```

proves that the API server owns that certificate.

---

# 6. Why does `apiserver.crt` need SANs?

This is extremely important for interviews.

The API server may be accessed through:

```text
10.0.0.10
10.96.0.1
kubernetes
kubernetes.default
kubernetes.default.svc
kubernetes.default.svc.cluster.local
control-plane.example.com
```

Therefore the certificate needs appropriate **Subject Alternative Names (SANs)**.

You can inspect:

```bash
openssl x509 \
  -in /etc/kubernetes/pki/apiserver.crt \
  -noout \
  -text
```

Look for:

```text
X509v3 Subject Alternative Name:
```

---

# 7. API Server → Kubelet Certificate

Now we get to your previous question.

These files:

```text
/etc/kubernetes/pki/apiserver-kubelet-client.crt
/etc/kubernetes/pki/apiserver-kubelet-client.key
```

are used when:

```text
kube-apiserver
       |
       | HTTPS + client certificate
       ↓
    kubelet
```

The API server needs to authenticate itself to the kubelet.

So:

```text
kube-apiserver
     |
     | presents:
     |
     | apiserver-kubelet-client.crt
     | apiserver-kubelet-client.key
     |
     ↓
   kubelet
```

This is different from:

```text
kubelet
   |
   | client certificate
   ↓
API server
```

Those are **opposite directions**.

---

# 8. Kubelet PKI

Kubelet has its own PKI directory:

```text
/var/lib/kubelet/pki/
```

You may see:

```text
/var/lib/kubelet/pki/
│
├── kubelet-client-current.pem
├── kubelet-client-2026-....pem
├── kubelet.crt
└── kubelet.key
```

Depending on kubeadm/Kubernetes version and configuration, the exact files can differ.

The important distinction is:

```text
kubelet-client-current.pem
```

is a **client certificate/key** used by kubelet to authenticate to the API server.

---

# 9. Your Previous Question Explained

You saw:

```yaml
users:
- name: default-auth
  user:
    client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
    client-key: /var/lib/kubelet/pki/kubelet-client-current.pem
```

This means:

```text
                 kubelet-client-current.pem
                         |
             +-----------+-----------+
             |                       |
             ↓                       ↓
       Certificate               Private Key
             |                       |
             ↓                       ↓
   client-certificate          client-key
```

The same PEM file can contain both:

```text
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----

-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

So there is nothing wrong with this configuration.

---

# 10. Kubelet Authentication Flow

The complete flow:

```text
                    Kubernetes CA
                         |
                         | signs
                         ↓
              kubelet client certificate
                         |
                         ↓
                       kubelet
                         |
                         | HTTPS
                         |
                         ↓
                  kube-apiserver
```

The kubelet presents its client certificate.

Its identity might look like:

```text
CN = system:node:worker01
O  = system:nodes
```

This is very important.

Kubernetes uses the certificate's identity to determine **who the client is**.

---

# 11. `system:node:*`

For example:

```text
CN=system:node:worker01
O=system:nodes
```

Kubernetes interprets this as:

```text
User:
system:node:worker01

Group:
system:nodes
```

Then RBAC determines what this identity can do.

So:

```text
Certificate
     |
     ↓
CN / Organization
     |
     ↓
Kubernetes identity
     |
     ↓
RBAC
     |
     ↓
Permissions
```

This is a very important interview concept.

---

# 12. Controller Manager Certificate

The controller manager communicates with the API server.

It uses:

```text
/etc/kubernetes/controller-manager.conf
```

Inside that kubeconfig is a client identity.

Conceptually:

```text
kube-controller-manager
          |
          | client certificate
          |
          ↓
    kube-apiserver
```

The kubeconfig references its certificate/key or embeds them as data.

---

# 13. Scheduler Certificate

Similarly:

```text
kube-scheduler
      |
      | client certificate
      ↓
kube-apiserver
```

Usually configured through:

```text
/etc/kubernetes/scheduler.conf
```

---

# 14. Admin Certificate

The administrator commonly uses:

```text
/etc/kubernetes/admin.conf
```

This contains:

```text
cluster
user
context
```

The user credentials contain a client certificate and private key.

Conceptually:

```text
kubectl
   |
   | admin client certificate
   |
   ↓
API Server
   |
   ↓
Authentication
   |
   ↓
Authorization / RBAC
```

Modern kubeadm generates an administrator identity in `admin.conf` associated with the `kubeadm:cluster-admins` group, while `super-admin.conf` uses `system:masters`. ([Kubernetes][1])

---

# 15. `admin.conf` vs `kubelet.conf`

This is another common interview question.

### Admin

```text
/etc/kubernetes/admin.conf
```

Used by:

```text
kubectl
```

Identity:

```text
kubernetes-admin
```

### Kubelet

```text
/etc/kubernetes/kubelet.conf
```

Used by:

```text
kubelet
```

Identity associated with the node.

So:

```text
admin.conf
     ↓
Administrator → API Server


kubelet.conf
     ↓
Kubelet → API Server
```

---

# 16. etcd Has Its Own CA

Now we have a completely separate PKI hierarchy.

```text
/etc/kubernetes/pki/etcd/
```

The CA:

```text
etcd/ca.crt
etcd/ca.key
```

Think:

```text
                    etcd CA
                      |
          +-----------+------------+
          |           |            |
          ↓           ↓            ↓
       Server       Peer       Client
       cert         cert        cert
```

Why a separate CA?

Because etcd is a critical data store and has its own TLS trust domain.

Kubernetes documents a separate `etcd-ca` for etcd-related functions. ([Kubernetes][1])

---

# 17. etcd Server Certificate

Files:

```text
etcd/server.crt
etcd/server.key
```

This identifies the etcd server.

Communication:

```text
kube-apiserver
       |
       | TLS
       ↓
      etcd
```

The API server verifies that it is actually talking to a trusted etcd server.

---

# 18. etcd Peer Certificate

Files:

```text
etcd/peer.crt
etcd/peer.key
```

These are used for communication between etcd members.

For example:

```text
etcd-1
  |
  | mTLS
  |
  +-------- etcd-2
  |
  | mTLS
  |
  +-------- etcd-3
```

This is particularly important in an HA control plane.

---

# 19. etcd Healthcheck Client Certificate

Files:

```text
etcd/healthcheck-client.crt
etcd/healthcheck-client.key
```

Used for health checking etcd.

Conceptually:

```text
health check
     |
     | client certificate
     ↓
   etcd
```

---

# 20. API Server → etcd Client Certificate

Files:

```text
etcd/apiserver-etcd-client.crt
etcd/apiserver-etcd-client.key
```

This is extremely important.

The API server is an **etcd client**.

Therefore:

```text
                  API Server
                      |
                      |
            apiserver-etcd-client.crt
            apiserver-etcd-client.key
                      |
                      ↓
                     etcd
```

The API server uses this certificate to authenticate to etcd.

---

# 21. Complete API Server ↔ etcd PKI

Think:

```text
                    etcd CA
                       |
                       |
             +---------+---------+
             |                   |
             ↓                   ↓
       etcd server          API Server
       certificate          etcd-client
             |              certificate
             |                   |
             +--------+----------+
                      |
                      ↓
                 Mutual TLS
```

---

# 22. Front-Proxy CA

Another CA:

```text
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
```

This is used by the **API aggregation layer**.

For example:

```text
                    kube-apiserver
                          |
                          |
                  Aggregation Layer
                          |
                          ↓
                 Extension API Server
```

Examples of aggregated APIs include extension API servers such as metrics-related APIs.

The front-proxy CA is required when using the API server aggregation layer. ([Kubernetes][1])

---

# 23. Front-Proxy Client Certificate

Files:

```text
front-proxy-client.crt
front-proxy-client.key
```

This certificate is signed by:

```text
front-proxy-ca
```

Flow:

```text
                front-proxy-ca
                     |
                     | signs
                     ↓
             front-proxy-client
                     |
                     ↓
              kube-apiserver
                     |
                     ↓
          Extension API Server
```

---

# 24. ServiceAccount PKI

Now something slightly different.

You have:

```text
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
```

These are **not CA certificates**.

They are a public/private key pair used for signing ServiceAccount tokens. ([Kubernetes][1])

Think:

```text
              sa.key
                |
                | signs
                ↓
       ServiceAccount token
                |
                ↓
          Pod → API Server
                |
                |
             sa.pub
                |
                ↓
             verifies
```

So:

```text
sa.key = private signing key
sa.pub = public verification key
```

---

# 25. ServiceAccount vs X.509 Authentication

Very important distinction:

### X.509

```text
admin
kubelet
scheduler
controller-manager
API server
etcd
```

can use:

```text
certificate + private key
```

### ServiceAccount

Pods commonly authenticate using:

```text
ServiceAccount token
```

signed using:

```text
sa.key
```

So don't say:

> "ServiceAccount uses the Kubernetes CA."

That's not the normal mechanism.

---

# 26. Complete Kubernetes PKI Tree

Here's the structure you should memorize:

```text
/etc/kubernetes/
│
├── admin.conf
├── controller-manager.conf
├── scheduler.conf
├── kubelet.conf
│
└── pki/
    │
    │
    ├── Kubernetes CA
    │   ├── ca.crt
    │   └── ca.key
    │
    ├── API Server
    │   ├── apiserver.crt
    │   └── apiserver.key
    │
    ├── API Server → Kubelet
    │   ├── apiserver-kubelet-client.crt
    │   └── apiserver-kubelet-client.key
    │
    ├── Front Proxy CA
    │   ├── front-proxy-ca.crt
    │   ├── front-proxy-ca.key
    │   ├── front-proxy-client.crt
    │   └── front-proxy-client.key
    │
    ├── ServiceAccount
    │   ├── sa.key
    │   └── sa.pub
    │
    └── etcd/
        │
        ├── etcd CA
        │   ├── ca.crt
        │   └── ca.key
        │
        ├── etcd Server
        │   ├── server.crt
        │   └── server.key
        │
        ├── etcd Peer
        │   ├── peer.crt
        │   └── peer.key
        │
        ├── etcd Healthcheck Client
        │   ├── healthcheck-client.crt
        │   └── healthcheck-client.key
        │
        └── API Server → etcd
            ├── apiserver-etcd-client.crt
            └── apiserver-etcd-client.key
```

This is the **core kubeadm PKI structure**. ([Kubernetes][1])

---

# 27. Worker Node PKI

The worker node has a slightly different structure.

For example:

```text
worker01
│
├── /etc/kubernetes/
│   └── kubelet.conf
│
└── /var/lib/kubelet/pki/
    ├── kubelet-client-current.pem
    ├── kubelet-client-<timestamp>.pem
    ├── kubelet.crt
    └── kubelet.key
```

The worker's kubelet needs two TLS identities:

```text
1. Client identity
2. Server identity
```

---

# 28. Kubelet Client Certificate

This is:

```text
kubelet-client-current.pem
```

Used for:

```text
kubelet
   |
   | client authentication
   ↓
API server
```

Identity typically resembles:

```text
CN=system:node:worker01
O=system:nodes
```

---

# 29. Kubelet Server Certificate

The API server also needs to communicate **to the kubelet**.

So kubelet can have a serving certificate:

```text
kubelet.crt
kubelet.key
```

Flow:

```text
API Server
    |
    | HTTPS
    ↓
 Kubelet HTTPS endpoint
```

The API server authenticates the kubelet's serving certificate according to its configured trust settings.

Kubernetes officially distinguishes kubelet server and client certificates. ([Kubernetes][1])

---

# 30. The Most Important Communication Diagram

If you memorize only one diagram, memorize this:

```text
                         Kubernetes CA
                              |
          +-------------------+------------------+
          |                   |                  |
          ↓                   ↓                  ↓
    API Server            Kubelet            Components
    Server Cert          Client Cert
          |
          |
          | HTTPS
          |
          +----------------------+
          |                      |
          ↓                      ↓
       kubectl                 kubelet
       admin                   client
          |
          |
          ↓
     kube-apiserver
          |
          |
          | apiserver-etcd-client
          |
          ↓
        etcd
          |
          |
       etcd CA
          |
     +----+----+
     |         |
     ↓         ↓
   Server     Peer
   Cert       Cert


                 Front Proxy CA
                       |
                       ↓
              Front Proxy Client
                       |
                       ↓
                API Aggregation
                       |
                       ↓
              Extension API Server


                  ServiceAccount
                       |
                     sa.key
                       |
                       ↓
                   JWT/token
                       |
                       ↓
                    Pod
                       |
                       ↓
                 API Server
```

---

# 31. Who Talks to Whom?

This table is excellent for interviews:

| Component          | Talks to             | Authentication                        |
| ------------------ | -------------------- | ------------------------------------- |
| `kubectl`          | API Server           | Admin client certificate / token      |
| Kubelet            | API Server           | Kubelet client certificate            |
| API Server         | Kubelet              | API-server kubelet client certificate |
| Scheduler          | API Server           | Scheduler client certificate          |
| Controller Manager | API Server           | Controller-manager client certificate |
| API Server         | etcd                 | `apiserver-etcd-client` certificate   |
| etcd               | etcd                 | Peer certificates                     |
| etcd health check  | etcd                 | Healthcheck client certificate        |
| API Server         | Extension API Server | Front-proxy certificates              |
| Pod                | API Server           | ServiceAccount token                  |

---

# 32. Certificate vs CA vs Private Key

Don't mix these three.

### CA

```text
ca.crt
ca.key
```

CA can sign other certificates.

### Server certificate

```text
apiserver.crt
apiserver.key
```

Identifies a server.

### Client certificate

```text
kubelet-client.crt
kubelet-client.key
```

Identifies a client.

So:

```text
                    CA
                     |
                 signs cert
                     |
          +----------+----------+
          |                     |
       Server                 Client
       Cert                   Cert
          |                     |
       Server                  Client
```

---

# 33. Certificate Authentication Flow

For example, kubelet:

```text
                kubelet
                   |
                   |
         client certificate
                   |
                   ↓
              API Server
                   |
                   ↓
             Verify certificate
                   |
                   ↓
            Kubernetes CA
                   |
                   ↓
             Extract identity
                   |
             +-----+------+
             |            |
            CN             O
             |            |
             ↓            ↓
     system:node:01   system:nodes
             |
             ↓
            RBAC
             |
             ↓
          Permissions
```

This is the connection between **PKI and RBAC**.

---

# 34. How to See Your Cluster's PKI

On the control-plane node:

```bash
sudo find /etc/kubernetes/pki -type f -print
```

You can inspect:

```bash
sudo ls -lah /etc/kubernetes/pki
```

and:

```bash
sudo ls -lah /etc/kubernetes/pki/etcd
```

For kubelet:

```bash
sudo ls -lah /var/lib/kubelet/pki
```

---

# 35. Check Certificate Details

For example:

```bash
sudo openssl x509 \
  -in /etc/kubernetes/pki/apiserver.crt \
  -noout \
  -subject \
  -issuer \
  -dates
```

You get:

```text
subject=
issuer=
notBefore=
notAfter=
```

To inspect SANs:

```bash
sudo openssl x509 \
  -in /etc/kubernetes/pki/apiserver.crt \
  -noout \
  -text | grep -A2 "Subject Alternative Name"
```

---

# 36. Check Certificate Expiration

With kubeadm:

```bash
sudo kubeadm certs check-expiration
```

This is the recommended kubeadm command for checking expiration of the cluster's locally managed certificates. ([Kubernetes][2])

You may see something similar to:

```text
CERTIFICATE                EXPIRES
admin.conf                 ...
apiserver                  ...
apiserver-kubelet-client   ...
controller-manager.conf    ...
scheduler.conf             ...
```

---

# 37. Renew Certificates

For kubeadm:

```bash
sudo kubeadm certs renew all
```

Or selectively:

```bash
sudo kubeadm certs renew apiserver
```

```bash
sudo kubeadm certs renew apiserver-kubelet-client
```

```bash
sudo kubeadm certs renew admin.conf
```

After renewal, control-plane components may need restarting for the new certificates to take effect. ([Kubernetes][2])

---

# 38. One Critical Concept: CA Expiration

Suppose:

```text
ca.crt
ca.key
```

are your CA.

And:

```text
apiserver.crt
kubelet-client.crt
admin certificate
scheduler certificate
```

were signed by that CA.

If the CA itself expires or is compromised, you have a much bigger problem than one individual certificate expiring.

Think hierarchy:

```text
                 Kubernetes CA
                      |
        +-------------+-------------+
        |             |             |
        ↓             ↓             ↓
   API Server      Kubelet       Admin
   Certificate     Certificate   Certificate
```

The CA is the **trust anchor**.

---

# 39. Kubernetes PKI vs TLS

Another interview distinction:

### TLS

Provides:

```text
Encryption
Integrity
Authentication
```

### PKI

Provides the infrastructure around:

```text
CA
Certificates
Private Keys
Certificate Signing
Trust
Identity
```

So:

```text
PKI
 |
 +--- CA
 |
 +--- Certificates
 |
 +--- Private Keys
 |
 +--- Trust
 |
 +--- Identity
 |
 +--- Certificate lifecycle
```

Kubernetes uses this PKI infrastructure to secure communication between its components. ([Kubernetes][1])

---

# 40. The 10 Files/Groups You Should Know for Interviews

If an interviewer asks:

> "Explain Kubernetes PKI."

Start with these:

```text
1. ca.crt
2. ca.key

3. apiserver.crt
4. apiserver.key

5. apiserver-kubelet-client.crt
6. apiserver-kubelet-client.key

7. front-proxy-ca.crt
8. front-proxy-ca.key

9. sa.key
10. sa.pub
```

Then explain etcd:

```text
11. etcd/ca.crt
12. etcd/ca.key

13. etcd/server.crt
14. etcd/server.key

15. etcd/peer.crt
16. etcd/peer.key

17. etcd/apiserver-etcd-client.crt
18. etcd/apiserver-etcd-client.key
```

And finally:

```text
/var/lib/kubelet/pki/
```

for node-specific kubelet certificates.

---

# 41. The Interview Answer

If they ask:

> **"Explain Kubernetes PKI."**

You can answer:

> Kubernetes uses PKI and TLS to authenticate and encrypt communication between its components. In a kubeadm cluster, most control-plane certificates are stored under `/etc/kubernetes/pki`. The main trust domains are the Kubernetes CA, etcd CA, and front-proxy CA. The Kubernetes CA signs certificates used by the API server, kubelets, controller manager, scheduler and administrators. The etcd CA is used for etcd server, peer and client communication. The front-proxy CA is used for the API aggregation layer. Kubelets have node-specific certificates under `/var/lib/kubelet/pki`. Kubernetes also has `sa.key` and `sa.pub`, which are used for signing and verifying ServiceAccount tokens rather than X.509 authentication. The certificates establish identity, while RBAC determines what that identity is allowed to do.

That is a **strong DevOps/Kubernetes interview answer**. ([Kubernetes][1])

### The easiest mental model

```text
                    TRUST
                      │
          ┌───────────┼───────────┐
          │           │           │
     Kubernetes CA  etcd CA  Front Proxy CA
          │           │           │
          │           │           └── Aggregation
          │           │
          │           └── etcd TLS
          │
    ┌─────┼─────────────┐
    │     │      │      │
    ↓     ↓      ↓      ↓
   API  Kubelet Scheduler Controller
 Server            Manager
    │
    │
    └──────────→ etcd
```

**PKI establishes "WHO are you?" → Authentication.**
**RBAC establishes "WHAT can you do?" → Authorization.**

That separation is one of the most important concepts to understand for Kubernetes security.

[1]: https://kubernetes.io/docs/setup/best-practices/certificates/?utm_source=chatgpt.com "PKI certificates and requirements | Kubernetes"
[2]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-certs/?utm_source=chatgpt.com "kubeadm certs | Kubernetes"
