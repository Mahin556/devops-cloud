# etcd: The Distributed Key-Value Store for Kubernetes

Every Kubernetes resource you create (Pods, Services, Deployments) has to live somewhere. In this lesson, you'll install etcd, the distributed key-value store that holds the entire cluster state.

---

## 📋 Objectives

- Understand etcd's role within a Kubernetes cluster
- Install and configure etcd from scratch
- Learn how to interact with etcd using the `etcdctl` command-line tool
- Secure etcd with TLS certificates for encrypted communication

By the end of this lesson, you'll have etcd running with TLS encryption, ready to serve as the cluster's data store.

---

## 🔍 What is etcd?

etcd is a distributed key-value store that serves as the primary data store for all cluster state in Kubernetes. It stores configuration data, state information, and metadata for the entire cluster.

Originally developed by CoreOS, etcd is now maintained by the CNCF. It is designed to be **highly available**, **consistent**, and **reliable** — all essential qualities for the system that holds the "source of truth" for your entire Kubernetes cluster.

---

## 🧠 How etcd Works

etcd implements the **Raft consensus algorithm** to ensure consistency across multiple nodes. The cluster can continue operating even if some nodes fail, as long as a majority of nodes (a quorum) remain healthy.

![alt text](/images/image-4.png)

> **Note** 💡 etcd clusters typically run with an odd number of nodes (3, 5, or 7) to maintain proper quorum.

etcd's strong consistency guarantee requires that all consistency-sensitive operations (for example, any write operations) flow through a **leader node**, which gets elected through the Raft consensus algorithm.

![alt text](/images/image-5.png)

> **Note** 💡 In case of leader failure, the remaining nodes automatically elect a new leader.

Strong consistency is essential for Kubernetes to ensure that all components see the same cluster state. Without this guarantee, Kubernetes could schedule Pods on nodes lacking capacity, or controllers could make conflicting decisions based on stale data.

---

## 🏗️ etcd and the Kubernetes API Server

Only the **Kubernetes API server** communicates directly with etcd. All other components (like kubelet, scheduler, and controllers) interact with cluster state through the API server, which acts as a gateway to etcd.

![alt text](/images/image-6.png)

This design keeps etcd safe from direct access by cluster components and centralizes control over authentication, authorization, admission, and validation to ensure the cluster state stays valid and consistent.

![alt text](/images/image-7.png)
---

## 📦 Installing etcd

etcd is available from the project's [GitHub Releases page](https://github.com/etcd-io/etcd/releases).

### Download and install etcd:

```bash
ETCD_VERSION=v3.6.4

curl -fsSLO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION?}/etcd-${ETCD_VERSION?}-linux-amd64.tar.gz"

tar xzvof "etcd-${ETCD_VERSION?}-linux-amd64.tar.gz"

sudo install -m 755 "etcd-${ETCD_VERSION?}-linux-amd64"/{etcd,etcdctl,etcdutl} /usr/local/bin

etcdctl completion bash | sudo tee /etc/bash_completion.d/etcdctl
```

📌 *Start playground to activate this check*

---

## 👤 Create a Dedicated User for etcd

```bash
sudo adduser \
    --system \
    --group \
    --disabled-login \
    --disabled-password \
    --home /var/lib/etcd \
    etcd

getent passwd etcd
```

📌 *Start playground to activate this check*

---

## ⚙️ Systemd Unit File

Download the systemd unit file for etcd:

```bash
sudo wget -O /etc/systemd/system/etcd.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/01-etcd/__static__/etcd.service?v=1777378794
```
```bash
[Unit]
Description=etcd - Highly-available key value store
Documentation=https://etcd.io
After=network.target
Wants=network-online.target

[Service]
Type=notify

User=etcd
WorkingDirectory=/var/lib/etcd

ExecStart=/usr/local/bin/etcd

Environment=ETCD_DATA_DIR=/var/lib/etcd
EnvironmentFile=-/etc/default/%p

Restart=on-failure
RestartSec=5

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```


📌 *Start playground to activate this check*

### Start the etcd service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now etcd
```

---

## 🛠️ Interacting with etcd

With etcd installed and running, you can now explore its capabilities.

etcd exposes both HTTP and gRPC APIs. You can test the HTTP API using `curl`:

```bash
curl http://127.0.0.1:2379/health
```

However, `etcdctl` provides a more convenient way to interact with etcd:

```bash
etcdctl endpoint health
etcdctl endpoint health --endpoints=http://127.0.0.1:2379
```

📌 *Start playground to activate this check*

---

## 🔑 Basic Key-Value Operations

As a key-value store, etcd allows you to store and retrieve data in the form of key-value pairs:

```bash
etcdctl put foo bar
```

📌 *Start playground to activate this check*

### Retrieve data from the store:

```bash
etcdctl get foo
```

By default, `etcdctl` returns both the key and the value. To retrieve only the value, use the `--print-value-only` flag:

```bash
etcdctl get foo --print-value-only
```

---

## 📂 Hierarchical Data Organization

etcd supports prefix-based key retrieval using the `--prefix` flag, allowing you to organize data in a hierarchical structure (like Kubernetes does).

### Create some keys with a path-like structure:

```bash
etcdctl put /foo bar
etcdctl put /foo/bar baz
etcdctl put /foo/bar/baz bat
```

📌 *Start playground to activate this check*

### Retrieve all keys that start with `/foo`:

```bash
etcdctl get --prefix /foo --keys-only
```

---

## 🔒 Securing etcd with TLS

> **⚠️ Important:** The configuration used in this section may not meet your organization's security standards.  
> Follow your organization's security policies and guidelines for managing certificates in production environments.

**Securing etcd with TLS is critical in any production Kubernetes cluster.** Without proper TLS encryption, sensitive information travels in plaintext over the wire.

This exposes critical data to anyone who can intercept network traffic:

- ServiceAccount tokens
- TLS certificates
- Cluster configuration
- Secrets and ConfigMaps

TLS provides more than just encryption, though. It also enables authenticating clients via **mTLS (mutual TLS)** authentication, ensuring that only authorized components can access or modify cluster state data.

---

## 🛡️ Setting Up TLS for etcd

Setting up TLS for etcd requires generating the necessary certificates and keys.

### Create a directory:

```bash
sudo mkdir -p /etc/etcd/pki
cd /etc/etcd/pki
```

### Create a Certificate Authority (CA) to sign certificates:

```bash
sudo openssl genrsa -out ca.key 4096
sudo openssl req -x509 -new -nodes -key ca.key -out ca.crt -subj "/CN=etcd" -sha256 -days 3650
```

📌 *Start playground to activate this check*

> **Note** 💡 Although you could create separate CAs for server and client certificates, common Kubernetes deployment tools like `kubeadm` use a single CA.

---

### Create a config file for the server certificate:

```bash
cat <<EOF | sudo tee server.cnf
[ req ]

default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[ req_distinguished_name ]

CN = server

[ req_ext ]

subjectAltName = @alt_names

[ alt_names ]

DNS.1 = localhost
DNS.2 = $(hostname)

IP.1 = 127.0.0.1
IP.2 = ::1
EOF

i=3
for ip in $(ip -o -4 addr show | awk '$2 != "lo" {split($4,a,"/"); print a[1]}'); do
    echo "IP.$i = $ip" | sudo tee -a server.cnf
    i=$((i+1))
done
```

### Generate the server certificate:

```bash
sudo openssl genrsa -out server.key 2048
sudo openssl req -new -key server.key -out server.csr -config server.cnf
sudo openssl x509 -req -in server.csr -out server.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365 -extfile server.cnf -extensions req_ext
```

📌 *Start playground to activate this check*

---

### Generate a client certificate for the Kubernetes API server and other etcd clients:

```bash
sudo openssl genrsa -out client.key 2048
sudo openssl req -new -key client.key -out client.csr -subj "/CN=etcd/O=etcd"
sudo openssl x509 -req -in client.csr -out client.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
```

📌 *Start playground to activate this check*

---

### Set ownership and permissions:

```bash
sudo chown -R etcd:etcd .
```

Make the client key accessible to all users:

```bash
sudo chmod 644 client.key
```

> **⚠️ Important:** This ensures all users (including the lab user) can authenticate with etcd. In production environments, this is **NOT** recommended.

Go back to the home directory:

```bash
cd
```

---

## ⚙️ Configuring etcd to Use TLS

Configure etcd to use TLS for server connections and mutual TLS for client authentication:

```bash
cat <<EOF | sudo tee -a /etc/default/etcd

ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379

ETCD_CLIENT_CERT_AUTH=true
ETCD_CERT_FILE=/etc/etcd/pki/server.crt
ETCD_KEY_FILE=/etc/etcd/pki/server.key
ETCD_TRUSTED_CA_FILE=/etc/etcd/pki/ca.crt

ETCD_NAME=$(hostname)
ETCD_ADVERTISE_CLIENT_URLS=https://$(hostname):2379

EOF
```

### Configuration Variables:

| Variable | Description |
|----------|-------------|
| `ETCD_NAME` | etcd instances need a unique name (especially in a cluster) |
| `ETCD_CERT_FILE`, `ETCD_KEY_FILE` | Certificate and key files for serving TLS connections |
| `ETCD_CLIENT_CERT_AUTH` | Require client TLS authentication |
| `ETCD_TRUSTED_CA_FILE` | CA for verifying client certificates |

📌 *Start playground to activate this check*

> **Note** 💡 etcd supports multiple configuration methods. Refer to this [playground](https://labs.iximiuz.com/playgrounds/etcd-io-d6418264) and the [official documentation](https://etcd.io/docs/latest/).

---

### Restart the etcd service to apply the changes:

```bash
sudo systemctl restart etcd
```

---

## 🖥️ Configuring etcdctl for TLS

Configure `etcdctl` to communicate with etcd using TLS:

```bash
cat <<EOF | tee -a "$HOME/.bashrc" "$HOME/.profile"

export ETCDCTL_CACERT=/etc/etcd/pki/ca.crt
export ETCDCTL_CERT=/etc/etcd/pki/client.crt
export ETCDCTL_KEY=/etc/etcd/pki/client.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
EOF
```

📌 *Start playground to activate this check*

### Verify that you can communicate with etcd using TLS:

```bash
bash --login -c "etcdctl endpoint health"
```

📌 *Start playground to activate this check*

---

## ✅ Summary

With these certificates in place, etcd now provides **secure, encrypted communication** with authenticated clients, adding an essential layer of protection to your cluster's data store.

---

## 📚 Lesson Recap

In this lesson, you learned about etcd, the distributed key-value store that serves as the backbone of every Kubernetes cluster.

### Key Takeaways:

- **Cluster state storage:** etcd serves as the single source of truth for all Kubernetes cluster data, storing configuration, state information, and metadata with strong consistency guarantees
- **Raft consensus algorithm:** Ensures data consistency and high availability across multiple nodes, with automatic leader election and the ability to survive node failures as long as a majority remains healthy
- **API server gateway:** Only the Kubernetes API server communicates directly with etcd, providing centralized access control and keeping etcd protected from direct component access
- **Key-value operations:** Supports hierarchical data organization through prefix-based queries, enabling efficient storage and retrieval of Kubernetes resource information
- **TLS security:** Provides encrypted communication and mutual authentication between etcd servers and clients, protecting sensitive cluster data during transmission

With etcd running and secured with TLS, you have established the foundational data layer that will store all your cluster's state.

**Next**, you'll install `kube-apiserver`, the control plane component that will serve as the gateway to etcd and expose the Kubernetes API.

---

## 📖 Additional Resources

💡 To learn more about the concepts covered in this lesson, check out the resources below.

### 🧪 Playgrounds
- [etcd](https://labs.iximiuz.com/playgrounds/etcd-io-d6418264)
- [etcd Cluster](https://labs.iximiuz.com/playgrounds/etcd-cluster-e368a3ff)

### 📚 Learning Resources
- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- https://raft.github.io/
- https://etcd.io/
- https://etcd.io/docs/latest/learning
- https://etcd.io/docs/latest/quickstart