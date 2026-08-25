# kube-apiserver: The Gateway to Your Kubernetes Cluster

Every Kubernetes component needs to read and write cluster state, but letting them all talk to etcd directly would be chaos. In this lesson, you'll install `kube-apiserver`, the single entry point that authenticates, validates, and coordinates all access to the cluster.

---

## 📋 Objectives

- Understand `kube-apiserver`'s role within a Kubernetes cluster
- Install and configure `kube-apiserver` from scratch
- Configure authentication and authorization to secure access to the cluster
- Interact with the Kubernetes API directly using `curl`
- Install and configure `kubectl`, the Kubernetes CLI
- Secure `kube-apiserver` with TLS certificates for encrypted communication
- Explore how `kube-apiserver` stores data in etcd

By the end of this lesson, you'll have a secured API server connected to etcd, accessible via `kubectl`.

---

> **Important** 🐛 Reporting issues  
> If you encounter any issues throughout the course, please report them [here](https://github.com/kubernetes/kubernetes/issues).

---

## 🧠 What is kube-apiserver?

`kube-apiserver` serves as the **frontend** for the Kubernetes control plane and the central hub through which all cluster operations flow. It exposes the Kubernetes API and serves as the primary interface for managing the cluster, handling everything from creating Pods to managing Services and scaling Deployments.

Despite being a crucial control plane component, `kube-apiserver`'s primary function is straightforward: it processes REST operations, validates them, and updates the corresponding objects in etcd.

### Critical Roles of kube-apiserver

- **Gateway to etcd**: The only component that directly reads from and writes to the cluster's persistent state
- **Central communication hub**: All other Kubernetes components communicate exclusively through `kube-apiserver`
- **Security enforcer**: Every request must pass through its authentication, authorization, and validation layers
- **State coordinator**: Ensures all components have a consistent view of the cluster's desired and actual state

Without `kube-apiserver`, Kubernetes simply cannot function.  
Every `kubectl` command, every controller action, every kubelet update — all of it flows through this single, critical component.

![alt text](/images/image-8.png)

---

## 📦 Installing kube-apiserver

Download and install `kube-apiserver`:

```bash
KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-apiserver"

sudo install -m 755 kube-apiserver /usr/local/bin
```

📌 *Start playground to activate this check*

---

## ⚙️ Systemd Unit File

Download the systemd unit file for `kube-apiserver`:

```bash
sudo wget -O /etc/systemd/system/kube-apiserver.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/02-kube-apiserver/__static__/kube-apiserver.service?v=1777378795
```

📌 *Start playground to activate this check*

With `kube-apiserver` installed, you can now configure it. But first, you need to set up a few prerequisites.

---

## 🔐 Prerequisites: Service Account Keys

Create a directory for `kube-apiserver` certificates:

```bash
sudo mkdir -p /etc/kubernetes/pki
cd /etc/kubernetes/pki
```

Generate the service account keys that `kube-apiserver` will use to sign service account tokens:

```bash
(
sudo mkdir -p /etc/kubernetes/pki
cd /etc/kubernetes/pki
sudo openssl genrsa -out sa.key 2048
sudo openssl rsa -in sa.key -pubout -out sa.pub
)
```

📌 *Start playground to activate this check*

---

## ⚙️ Configuring kube-apiserver

Configure `kube-apiserver` with the required flags. The configuration includes:

- **Service cluster IP range**: CIDR notation IP range for assigning service cluster IPs
- **Service account keys**: Paths to the signing and public keys for service account tokens
- **etcd connection**: Configuration for connecting to the etcd cluster

> **Note** 💡 Unlike other Kubernetes components, `kube-apiserver` is configured primarily through command-line flags rather than configuration files.  
> This means you'll need to edit the systemd unit file and add the necessary command-line flags.

Edit the systemd unit file to add these flags:

**/etc/systemd/system/kube-apiserver.service**

```ini
[Unit]
# ...

[Service]
# ...

ExecStart=/usr/local/bin/kube-apiserver \
    --service-cluster-ip-range=10.96.0.0/12 \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --service-account-key-file=/etc/kubernetes/pki/sa.pub \
    --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \
    --etcd-cafile=/etc/etcd/pki/ca.crt \
    --etcd-certfile=/etc/etcd/pki/client.crt \
    --etcd-keyfile=/etc/etcd/pki/client.key \
    --etcd-servers=https://127.0.0.1:2379

# ...
```

Reload the systemd daemon to apply the changes and start the `kube-apiserver` service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kube-apiserver
sudo systemctl status kube-apiserver --no-pager
```

---

## 🔑 Configuring Authentication & Authorization

Before `kube-apiserver` can accept requests, it needs to know who is making the request (authentication) and what they're allowed to do (authorization).

By default, `kube-apiserver` allows anonymous requests and has no authorization controls configured — clearly unsuitable for production clusters.

`kube-apiserver` ships with these defaults:

- **Anonymous authentication**: Enabled
- **Authorization mode**: `AlwaysAllow` (permits every request)

However, this combination is invalid: the API server doesn't allow anonymous authentication with `AlwaysAllow` mode. When using this combination, the API server automatically disables anonymous authentication.

To access the API server, you must either configure a different authentication method or change the authorization mode.

---

### Configure Authentication

`kube-apiserver` supports several authentication methods.  
In this lesson, you'll configure and use **static token-based authentication**.

> **Note** 🔜 X.509 client certificate-based authentication (which is what many production clusters use) will be covered later in the lesson.

Static tokens can be configured via creating a token file. Token files are CSV files with a minimum of 3 columns: `token, user name, user uid`, followed by optional group names.

Create a token file with an admin user:

```bash
echo "iximiuz,admin,admin,system:masters" | sudo tee /etc/kubernetes/tokens.csv
```

📌 *Start playground to activate this check*

> **Note** 💡 The `system:masters` group membership grants superuser access to the API server.

Configure `kube-apiserver` to use the token file and disable anonymous authentication:

**/etc/systemd/system/kube-apiserver.service**

```ini
[Unit]
# ...

[Service]
# ...

ExecStart=/usr/local/bin/kube-apiserver \
    --service-cluster-ip-range=10.96.0.0/12 \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --service-account-key-file=/etc/kubernetes/pki/sa.pub \
    --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \
    --etcd-cafile=/etc/etcd/pki/ca.crt \
    --etcd-certfile=/etc/etcd/pki/client.crt \
    --etcd-keyfile=/etc/etcd/pki/client.key \
    --etcd-servers=https://127.0.0.1:2379 \
    --anonymous-auth=false \
    --token-auth-file=/etc/kubernetes/tokens.csv

# ...
```

```bash
sudoedit /etc/systemd/system/kube-apiserver.service
```

---

### Configure Authorization

Kubernetes supports several authorization modes:

- `AlwaysAllow`: Allows all requests (default)
- `AlwaysDeny`: Denies all requests
- `ABAC`: Attribute-Based Access Control
- `RBAC`: Role-Based Access Control
- `Node`: Special-purpose mode that grants permissions to kubelets
- `Webhook`: Uses an external service for authorization decisions

Although you could keep the authorization mode as `AlwaysAllow`, this isn't realistic for production environments. Production clusters typically use `RBAC` and `Node` authorization modes, so you'll configure the API server to use those.

> **Note** 💡 You can configure multiple authorization modes: they are evaluated in order, and if one explicitly allows the request, access is granted immediately; if it doesn't, the next one is tried; if none allow it, the request is denied by default.  
> You won't notice much difference since the admin user is a member of `system:masters`, which provides full API server access.

Configure `kube-apiserver` to use RBAC and Node authorization:

**/etc/systemd/system/kube-apiserver.service**

```ini
[Unit]
# ...

[Service]
# ...

ExecStart=/usr/local/bin/kube-apiserver \
    --service-cluster-ip-range=10.96.0.0/12 \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --service-account-key-file=/etc/kubernetes/pki/sa.pub \
    --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \
    --etcd-cafile=/etc/etcd/pki/ca.crt \
    --etcd-certfile=/etc/etcd/pki/client.crt \
    --etcd-keyfile=/etc/etcd/pki/client.key \
    --etcd-servers=https://127.0.0.1:2379 \
    --anonymous-auth=false \
    --token-auth-file=/etc/kubernetes/tokens.csv \
    --authorization-mode=Node,RBAC

# ...
```

```bash
sudoedit /etc/systemd/system/kube-apiserver.service
```

---

### Restart kube-apiserver

Reload the systemd daemon and restart the `kube-apiserver` service to apply the changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kube-apiserver
```

📌 *Start playground to activate this check*

---

### Test Authentication

Verify that `kube-apiserver` now requires authentication by testing both authenticated and unauthenticated requests.

> **Important** ⚠️ This command will fail because no authentication token is provided.

```bash
curl -f -k https://localhost:6443/api/v1/namespaces
```

Test with authentication (should succeed):

```bash
curl -f -k -H "Authorization: Bearer iximiuz" https://localhost:6443/api/v1/namespaces
```

📌 *Start playground to activate this check*

---

## 🌐 Working with the Kubernetes API via curl

The Kubernetes API is a REST API specification that defines the structure and behavior of the API server, allowing you to query and manipulate the state of objects in Kubernetes. This means you can interact with it using ordinary HTTP requests (for example, with tools like `curl`).

Understanding Kubernetes this way makes it less mysterious: at its core, it's just sending and receiving HTTP requests.

Although these terms are often used interchangeably, they have distinct meanings:

- **Kubernetes API**: The overall specification and set of endpoints that define how clients interact with the cluster.
- **API server**: The component within the Kubernetes control plane that implements the Kubernetes API.
- **kube-apiserver**: The reference implementation of the Kubernetes API, serving as the API server in most Kubernetes clusters.

Every Kubernetes resource (Pods, Services, Deployments, etc.) has its own API endpoint, following standard REST conventions.

The following examples demonstrate these operations in action.

### List all namespaces in the cluster

```bash
curl -f -k https://127.0.0.1:6443/api/v1/namespaces \
    -H "Authorization: Bearer iximiuz" \
    | jq -r '.items[].metadata.name'
```

### Create a new namespace

```bash
curl -f -k https://127.0.0.1:6443/api/v1/namespaces \
    -H "Authorization: Bearer iximiuz" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{
      "apiVersion": "v1",
      "kind": "Namespace",
      "metadata": {
        "name": "test-curl"
      }
    }'
```

### Verify the namespace was created

```bash
curl -f -k https://127.0.0.1:6443/api/v1/namespaces/test-curl \
    -H "Authorization: Bearer iximiuz" \
    | jq
```

📌 *Start playground to activate this check*

### Add a label to the namespace using a PATCH operation

```bash
curl -f -k https://127.0.0.1:6443/api/v1/namespaces/test-curl \
    -H "Authorization: Bearer iximiuz" \
    -X PATCH \
    -H "Content-Type: application/merge-patch+json" \
    -d '{"metadata": {"labels": {"foo": "bar"}}}'
```

### Verify the label was applied

```bash
curl -f -k https://127.0.0.1:6443/api/v1/namespaces/test-curl \
    -H "Authorization: Bearer iximiuz" \
    | jq '.metadata.labels'
```

📌 *Start playground to activate this check*

These examples demonstrate that Kubernetes resources are simply data structures accessible through standard HTTP operations: no magic, just REST API calls!

---

## 🖥️ Installing and Configuring kubectl

While using `curl` to interact with the API server demonstrates that it is fundamentally a REST API, it's time to introduce the standard CLI tool for interacting with Kubernetes: `kubectl`.

`kubectl` is the official command-line interface for Kubernetes that provides a more user-friendly way to interact with the API server.

### Download and install kubectl

```bash
KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kubectl"

sudo install -m 755 kubectl /usr/local/bin

kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl
```

📌 *Start playground to activate this check*

To use `kubectl`, you need to configure it to connect to your Kubernetes API server.

`kubectl` uses a configuration file called **kubeconfig** to store:

- cluster connection details
- authentication information
- context settings

The kubeconfig format follows the standard Kubernetes resource structure:

```yaml
apiVersion: v1
kind: Config
clusters: {}
contexts: {}
current-context: ""
users: {}
```

By default, `kubectl` looks for a kubeconfig file at `$HOME/.kube/config`.  
You can specify a different location using the:

- `--kubeconfig` flag
- `KUBECONFIG` environment variable

Instead of creating this configuration file manually, you can use `kubectl` itself to build it step by step.

### Add the cluster to the configuration

```bash
kubectl config set-cluster default \
    --insecure-skip-tls-verify \
    --server=https://localhost:6443
```

> **Important** ⚠️ `--insecure-skip-tls-verify` is strongly discouraged for production environments.  
> It's used here for simplicity since TLS hasn't been configured yet.

### Configure the credentials for your user

```bash
kubectl config set-credentials default \
    --token=iximiuz
```

### Create a context and set it as current

```bash
kubectl config set-context default \
    --cluster=default \
    --user=default

kubectl config use-context default
```

> **Note** 💡 A context groups access parameters under a convenient name, allowing you to switch between different clusters or users without modifying the configuration file directly.

📌 *Start playground to activate this check*

### Verify kubectl connectivity

```bash
kubectl cluster-info
```

### List all namespaces using kubectl

```bash
kubectl get namespaces
```

You should see the namespace you created earlier using `curl`.

### Try creating a new namespace using kubectl

```bash
kubectl create namespace test-kubectl
```

### Verify the namespace was created

```bash
kubectl get namespace test-kubectl
```

📌 *Start playground to activate this check*

From now on, you can use either `kubectl` commands or direct API calls with `curl`. Both accomplish the same tasks, but `kubectl` provides a more convenient interface.

> **Note** 💡 If you want to see what HTTP requests `kubectl` sends, you can use the verbosity flag:
> - `--v=6`: Shows the HTTP method, URL, and response status
> - `--v=7`: Adds request headers
> - `--v=8`: Adds response headers and truncated response body
> - `--v=9`: Shows everything including curl-equivalent commands

---

## 🔒 Securing kube-apiserver with TLS

> **⚠️ Important:** The configuration used in this section may not meet your organization's security standards.  
> Follow your organization's security policies and guidelines for managing certificates in production environments.

Securing `kube-apiserver` with TLS is critical for any production Kubernetes cluster: without proper TLS encryption, sensitive information travels in plaintext over the wire.

TLS provides more than just encryption, though. It also enables authenticating clients via **mTLS (mutual TLS)** and plays a crucial role in RBAC: client certificates can include organization fields that map to Kubernetes groups, ensuring only authorized users and components can access cluster resources.

If `kube-apiserver` starts without TLS certificates configured, it automatically generates self-signed certificates. While this enables basic HTTPS, these certificates do not provide reliable authentication and will trigger TLS verification warnings in clients.

Setting up TLS for `kube-apiserver` requires generating the necessary certificates and keys.

---

### Create a Certificate Authority (CA)

```bash
cd /etc/kubernetes/pki

sudo openssl genrsa -out ca.key 2048
sudo openssl req -x509 -new -nodes -key ca.key -out ca.crt \
  -subj "/CN=kubernetes" -sha256 -days 3650
```

📌 *Start playground to activate this check*

> **Note** 💡 Although you could create separate CAs for server and client certificates, common Kubernetes deployment tools (like `kubeadm`) use a single CA.

---

### Create server certificate configuration

```bash
cat <<EOF | sudo tee apiserver.cnf

[ req ]

default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[ req_distinguished_name ]

CN = kube-apiserver

[ req_ext ]

subjectAltName = @alt_names

[ alt_names ]

DNS.1 = localhost
DNS.2 = kubernetes
DNS.3 = kubernetes.default
DNS.4 = kubernetes.default.svc
DNS.5 = kubernetes.default.svc.cluster.local
DNS.6 = control-plane

IP.1 = 127.0.0.1
IP.2 = ::1
IP.3 = 10.96.0.1
EOF

i=4
for ip in $(ip -o -4 addr show | awk '$2 != "lo" {split($4,a,"/"); print a[1]}'); do
    echo "IP.$i = $ip" | sudo tee -a apiserver.cnf
    i=$((i+1))
done
```

> **Note** 💡 The `10.96.0.1` IP address is the first IP in the service cluster IP range. This IP gets automatically assigned to the `kubernetes` service in the default namespace.

---

### Generate the server certificate for the API server

```bash
sudo openssl genrsa -out apiserver.key 2048
sudo openssl req -new -key apiserver.key -out apiserver.csr -config apiserver.cnf
sudo openssl x509 -req -in apiserver.csr -out apiserver.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365 -extfile apiserver.cnf -extensions req_ext
```

📌 *Start playground to activate this check*

---

### Generate an admin client certificate with `system:masters` group membership

```bash
sudo openssl genrsa -out admin.key 2048
sudo openssl req -new -key admin.key -out admin.csr -subj "/CN=admin/O=system:masters"
sudo openssl x509 -req -in admin.csr -out admin.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
```

> **Note** 💡 The `O=system:masters` field (organization) in the certificate is translated to a Kubernetes group. Users in the `system:masters` group have cluster-admin privileges through RBAC.  
> This demonstrates how TLS certificates integrate with Kubernetes authorization.

📌 *Start playground to activate this check*

### Make the admin client key accessible to all users

```bash
sudo chmod 644 admin.key
```

> **⚠️ Important:** This ensures all users (including the lab user) can authenticate with the API server.  
> In production environments, this is **NOT** recommended.

---

### Update the kube-apiserver systemd service configuration

**/etc/systemd/system/kube-apiserver.service**

```ini
[Unit]
# ...

[Service]
# ...

ExecStart=/usr/local/bin/kube-apiserver \
    --service-cluster-ip-range=10.96.0.0/12 \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --service-account-key-file=/etc/kubernetes/pki/sa.pub \
    --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \
    --etcd-cafile=/etc/etcd/pki/ca.crt \
    --etcd-certfile=/etc/etcd/pki/client.crt \
    --etcd-keyfile=/etc/etcd/pki/client.key \
    --etcd-servers=https://127.0.0.1:2379 \
    --anonymous-auth=false \
    --token-auth-file=/etc/kubernetes/tokens.csv \
    --authorization-mode=Node,RBAC \
    --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \
    --tls-private-key-file=/etc/kubernetes/pki/apiserver.key \
    --client-ca-file=/etc/kubernetes/pki/ca.crt

# ...
```

```bash
sudoedit /etc/systemd/system/kube-apiserver.service
```

---

### Restart kube-apiserver

Reload the systemd daemon and restart the `kube-apiserver` service to apply the changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kube-apiserver
```

📌 *Start playground to activate this check*

---

### Configure kubectl to use TLS

Go back to the home directory:

```bash
cd
```

With TLS properly configured, configure `kubectl` to use secure connections with client certificate authentication:

```bash
kubectl config set-cluster default \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --server=https://localhost:6443

kubectl config set-credentials default \
    --client-certificate=/etc/kubernetes/pki/admin.crt \
    --client-key=/etc/kubernetes/pki/admin.key \
    --token=""

kubectl config set-context default \
    --cluster=default \
    --user=default

kubectl config use-context default
```

📌 *Start playground to activate this check*

### Verify secure connectivity

```bash
kubectl cluster-info
```

### Verify that the API server properly validates client certificates

```bash
curl -f https://127.0.0.1:6443/api/v1/namespaces \
    --cacert /etc/kubernetes/pki/ca.crt \
    --cert /etc/kubernetes/pki/admin.crt \
    --key /etc/kubernetes/pki/admin.key
```

📌 *Start playground to activate this check*

The `kube-apiserver` now provides **secure, encrypted communication** with proper certificate-based authentication, adding essential layers of security and enabling RBAC through certificate-based group membership.

---

## 🔍 Peeking into etcd: How kube-apiserver Stores Data

`kube-apiserver` is the gateway to etcd and the only component that directly reads from and writes to the cluster's persistent state. But what does that data actually look like inside etcd?

In this section, you'll peek behind the curtain and explore how Kubernetes resources are stored in etcd using `etcdctl`.

### Exploring the Key Structure

Kubernetes stores all its data under the `/registry` prefix in etcd.

List the keys to see the structure:

```bash
etcdctl get --prefix /registry --keys-only
```

Notice the pattern: keys follow the structure `/registry/<resource-type>/[<namespace>/]<name>`. This hierarchical layout mirrors the Kubernetes API structure you explored earlier.

For example, list the namespace keys:

```bash
etcdctl get --prefix /registry/namespaces --keys-only
```

You should see the default namespace, kube-system, and any namespaces you created earlier.

### Reading Objects From etcd

Try reading the `default` namespace object directly from etcd:

```bash
  
```

You'll see a mix of binary data with some recognizable strings scattered throughout.

This is because Kubernetes encodes objects using **Protocol Buffers (protobuf)** before storing them in etcd. Protobuf is a compact binary serialization format that is significantly more efficient than JSON or YAML, but it comes at the cost of readability.

---

### Decoding Objects With `auger`

To make sense of the binary data, you can use `auger`, a tool from the etcd project that decodes Kubernetes objects stored in etcd.

Download and install `auger`:

```bash
AUGER_VERSION=1.0.3

curl -fsSLO "https://github.com/etcd-io/auger/releases/download/v${AUGER_VERSION?}/auger_${AUGER_VERSION?}_linux_amd64.tar.gz"

tar xzvof "auger_${AUGER_VERSION?}_linux_amd64.tar.gz"

sudo install -m 755 {auger,augerctl} /usr/local/bin
```

📌 *Start playground to activate this check*

Now try reading the `default` namespace again, this time piping the output through `auger decode`:

```bash
etcdctl get /registry/namespaces/default --print-value-only | auger decode
```

The protobuf data is now decoded into a familiar YAML representation of the Namespace object — the same format you'd see from `kubectl get namespace default -o yaml`.

You can also output as JSON:

```bash
etcdctl get /registry/namespaces/default --print-value-only | auger decode -o json | jq
```

📌 *Start playground to activate this check*

This demonstrates an important concept: `kube-apiserver` is the translator between the human-readable API and the binary storage format in etcd. When you create a resource via `kubectl` or the REST API, `kube-apiserver` validates it, serializes it to protobuf, and writes it to etcd. When you read a resource, the process is reversed.

> **Note** 💡 If you want to learn more about how `kube-apiserver` processes requests, check out [this tutorial](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/).

---

## 📚 Lesson Recap

In this lesson, you learned about `kube-apiserver`, the frontend for the Kubernetes control plane and central hub through which all cluster operations flow.

### Key Takeaways

- **Central communication hub**: `kube-apiserver` serves as the only component that directly communicates with etcd and acts as the gateway through which all other Kubernetes components interact with cluster state
- **Security enforcement**: Every request passes through authentication (who you are), authorization (what you can do), and validation layers before reaching the cluster state
- **TLS encryption**: Provides secure, encrypted communication between clients and the API server, with proper certificate-based authentication for production environments
- **`kubectl` interface**: The official CLI tool translates user-friendly commands into API server requests, using kubeconfig files to manage cluster connection details and contexts
- **etcd storage**: Kubernetes objects are stored as protobuf-encoded data in etcd under the `/registry` prefix, and tools like `auger` can decode them for inspection

With `kube-apiserver` now running securely with TLS encryption and proper authentication, you have established the core control plane component that enables all Kubernetes functionality.

This foundation prepares you for adding other control plane components like the scheduler and controller manager to build a complete Kubernetes cluster.

---

## 📖 Additional Resources

💡 To learn more about the concepts covered in this lesson, check out the resources below.

### 🧪 Playgrounds
- [kube-apiserver](https://labs.iximiuz.com/playgrounds/kube-apiserver-e52fd50a)

### 📖 Tutorials
- [Kubernetes: Admission Control](https://labs.iximiuz.com/tutorials/kubernetes-admission-control-534baab1)

### 📚 Learning Resources
- https://kubernetes.io/docs/concepts/overview/kubernetes-api/
- https://kubernetes.io/docs/reference/kubernetes-api/
- https://kubernetes.io/docs/reference/using-api/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/concepts/security/controlling-access/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- https://kubernetes.io/docs/reference/kubectl/
- https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
- https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/
- https://kubernetes.io/docs/tasks/tls/
- https://kubernetes.io/docs/setup/best-practices/certificates/
- https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/
- https://github.com/etcd-io/auger
- https://kubespec.dev/kubernetes/v1/Namespace