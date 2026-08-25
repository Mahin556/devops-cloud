# CoreDNS: Service Discovery by Name

In this lesson, you'll set up CoreDNS, the cluster DNS server that enables service discovery by name in Kubernetes.

## 📋 Objectives

- Understand why DNS-based service discovery matters
- Learn the Kubernetes DNS naming convention for Services
- Configure kubelet to point Pods at the cluster DNS server
- Install CoreDNS on the control plane and configure it as a systemd service
- Route DNS queries from Pods to the CoreDNS instance running on the control-plane machine
- Understand the different name forms for reaching Services

By the end of this lesson, Pods will be able to reach Services by name instead of IP address, completing the cluster's networking stack.

---

## Service Discovery and DNS

In the previous lesson, you installed kube-proxy so that Services work through ClusterIPs. A client can now connect to a stable virtual IP and have traffic routed to the right Pods.

But there's still a problem: how does the client know the ClusterIP?

### The Last Mile

Right now, if you want to reach a Service, you need to look up its ClusterIP first:

```bash
kubectl get svc SVC_NAME -o jsonpath='{.spec.clusterIP}'
```

Then hardcode or pass that IP to your application. This is fragile for the same reason hardcoding Pod IPs was fragile: it creates tight coupling and breaks when things change.

> **Note** 💡 ClusterIP doesn't change on its own.  
> But the service may be recreated, leading to getting a new IP address.

What you really want is to reach a Service by name:

```bash
curl http://podinfo:80
```

This is **service discovery through DNS**, and it's how most Kubernetes applications find each other.

---

## The Kubernetes DNS Naming Convention

Kubernetes defines a predictable naming scheme for Services:

```
<service>.<namespace>.svc.<cluster-domain>
```

For example, a Service called `podinfo` in the `default` namespace with the default cluster domain:

```
podinfo.default.svc.cluster.local
```

Kubernetes also configures search domains in each Pod's `/etc/resolv.conf` so that you can use shorter names within the same namespace:

| Name form | When it works |
|-----------|---------------|
| `podinfo` | Same namespace |
| `podinfo.default` | Any namespace (qualified with namespace) |
| `podinfo.default.svc` | Explicit service qualifier |
| `podinfo.default.svc.cluster.local` | Fully qualified domain name (FQDN) |

All four resolve to the same ClusterIP. The short form (`podinfo`) is the most common in practice.

---

## Two Sides of DNS

Making DNS work in a Kubernetes cluster requires two things:

1. `kubelet` must configure each Pod's `/etc/resolv.conf` to point at the cluster DNS server
2. A DNS server must be running and reachable from Pods to answer those queries

kubelet handles the first part through two configuration options:

| Setting | Purpose | Example value |
|---------|---------|---------------|
| `clusterDNS` | IP address of the DNS server that kubelet writes into each Pod's `/etc/resolv.conf` | `10.96.0.10` |
| `clusterDomain` | The base domain for the cluster | `cluster.local` |

When kubelet starts a Pod, it writes `/etc/resolv.conf` with a `nameserver` entry pointing at the `clusterDNS` address and `search` entries derived from the `clusterDomain`.

> **Note** 💡 In standard Kubernetes distributions (e.g., kubeadm), clusterDNS typically points at a Service ClusterIP like `10.96.0.10`, with a `kube-dns` Service routing traffic to the CoreDNS Pods. In this course, CoreDNS runs directly on the control-plane machine, so `clusterDNS` points at the control-plane machine's IP address instead.

Right now, neither of these settings is configured on the worker nodes. You'll set them up first, then install the DNS server itself.

---

## Configuring kubelet for DNS

> **⚠️ Run the following steps on both `worker-1` and `worker-2`.**

The playground started a cluster with Flannel and kube-proxy already running. Cluster networking and Service ClusterIPs work, but DNS isn't configured yet.

### Adding the DNS Configuration

Create a kubelet configuration drop-in that sets the cluster DNS address and domain:

**/var/lib/kubelet/config.d/60-dns.conf**

```bash
cat <<EOF > /var/lib/kubelet/config.d/60-dns.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

clusterDNS:
  - 172.16.0.2
clusterDomain: cluster.local
EOF
```

```bash
sudoedit /var/lib/kubelet/config.d/60-dns.conf
```

📌 *Start playground to activate this check*  
📌 *Start playground to activate this check*

Restart kubelet on both workers to apply the changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

📌 *Start playground to activate this check*  
📌 *Start playground to activate this check*

---

## Deploying a Workload

> **Important** ⚠️ Switch to the control-plane machine.

Deploy a workload with a Service, plus a separate client Pod to test from:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:latest
          ports:
            - containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: podinfo
spec:
  selector:
    app: podinfo
  ports:
    - port: 80
      targetPort: 9898

---
apiVersion: v1
kind: Pod
metadata:
  name: client
spec:
  containers:
    - name: curl
      image: ghcr.io/stefanprodan/podinfo:latest
      command: ["sh", "-c", "sleep infinity"]
EOF
```

Wait for the Pods to start:

```bash
kubectl wait --for=condition=Available deployment podinfo
kubectl wait --for=condition=Ready pod client
```

📌 *Start playground to activate this check*

---

## Trying DNS

The Service has a ClusterIP and kube-proxy has programmed iptables rules for it. Reaching it from the client Pod by IP works:

```bash
CLUSTER_IP=$(kubectl get svc podinfo -o jsonpath='{.spec.clusterIP}')

kubectl exec client -- curl -fsS "http://${CLUSTER_IP}:80"
```

Now try reaching it by name:

```bash
kubectl exec client -- curl -fsS --max-time 5 "http://podinfo:80"
```

> **Important** ⚠️ This will fail because no DNS server is running on the control-plane machine yet.

Check the client Pod's DNS configuration:

```bash
kubectl exec client -- cat /etc/resolv.conf
```

You should see:

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 172.16.0.2
options ndots:5
```

kubelet configured the Pod's DNS correctly: it points at `172.16.0.2` (the control-plane machine) with the right search domains.

The problem is that no DNS server is running on the control-plane machine yet. The DNS query goes out, the packet reaches the control-plane machine, but nothing is listening on port 53.

---

## What is CoreDNS?

> **⚠️ Run the commands in this section on the control-plane machine.**

CoreDNS is a flexible, extensible DNS server written in Go. It's a CNCF graduated project and the default cluster DNS in Kubernetes.

CoreDNS watches the Kubernetes API for Services and Endpoints, then answers DNS queries based on the current cluster state. When a Pod asks "what's the IP of `podinfo.default.svc.cluster.local`?", CoreDNS looks up the matching Service and returns its ClusterIP.

Before CoreDNS, Kubernetes used `kube-dns` for cluster DNS. kube-dns was a combination of three containers (dnsmasq, a sidecar, and a Kubernetes-specific DNS server) bundled together.

CoreDNS replaced kube-dns as the default starting in Kubernetes 1.13. Its plugin-based architecture makes it easier to configure and extend. The Kubernetes plugin for CoreDNS handles the same job: watching the API server and answering DNS queries for Services, Pods, and other cluster resources.

In most Kubernetes distributions, CoreDNS runs as a Deployment inside the cluster. Since this course installs every component by hand, you'll install CoreDNS directly on the control-plane machine as a systemd service, just like every other cluster component.

---

## Prerequisites for CoreDNS

Like every other component that talks to the API server, CoreDNS needs to authenticate.

Generate a certificate and key for CoreDNS:

```bash
(
cd /etc/kubernetes/pki

sudo openssl genrsa -out coredns.key 2048
sudo openssl req -new -key coredns.key -out coredns.csr -subj "/CN=system:coredns"
sudo openssl x509 -req -in coredns.csr -out coredns.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
)
```

📌 *Start playground to activate this check*

Create a kubeconfig file for CoreDNS:

```bash
sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/coredns.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/coredns.conf \
    --client-certificate=/etc/kubernetes/pki/coredns.crt \
    --client-key=/etc/kubernetes/pki/coredns.key \
    --embed-certs=true

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/coredns.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/coredns.conf
```

📌 *Start playground to activate this check*

Grant CoreDNS the permissions it needs to read cluster state:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:coredns
rules:
  - apiGroups: [""]
    resources: ["endpoints", "services", "pods", "namespaces"]
    verbs: ["list", "watch"]
  - apiGroups: ["discovery.k8s.io"]
    resources: ["endpointslices"]
    verbs: ["list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:coredns
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
EOF
```

> **Note** 💡 Notice the `subjects` section uses `kind: User` instead of `kind: ServiceAccount`. When a component authenticates with a client certificate, the certificate's Common Name (CN) becomes the username. The certificate you generated has `CN=system:coredns`, so the ClusterRoleBinding grants permissions to that user.

📌 *Start playground to activate this check*

---

## Installing CoreDNS

Download and install CoreDNS:

```bash
COREDNS_VERSION=1.12.2

curl -fsSLO "https://github.com/coredns/coredns/releases/download/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz"
```

Extract and install the binary:

```bash
tar xzf coredns_${COREDNS_VERSION}_linux_amd64.tgz
sudo install -m 755 coredns /usr/local/bin
```

Create a dedicated system user for CoreDNS to run as:

```bash
sudo adduser \
    --system \
    --group \
    --disabled-login \
    --disabled-password \
    --home /var/lib/coredns \
    coredns
```

Now that the `coredns` user exists, let it read the kubeconfig file:

```bash
sudo chown coredns:coredns /etc/kubernetes/coredns.conf
```

📌 *Start playground to activate this check*

---

## Configuring CoreDNS

CoreDNS is configured through a file called a `Corefile`.

Create the configuration file:

**/etc/coredns/Corefile**

```
mkdir -p /etc/coredns/

cat <<EOF>/etc/coredns/Corefile
.:53 {
    bind eth0

    errors
    health {
        lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        kubeconfig /etc/kubernetes/coredns.conf
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
        ttl 30
    }
    forward . /etc/resolv.conf {
        max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
EOF
```

```bash
sudo mkdir -p /etc/coredns
sudoedit /etc/coredns/Corefile
```

| Directive | Purpose |
|-----------|---------|
| `bind eth0` | Only listen on the node's network interface (not all interfaces) |
| `errors` | Log errors to stdout |
| `health` | Expose a health check endpoint |
| `ready` | Expose a readiness endpoint at `:8181/ready` |
| `kubernetes cluster.local` | Enable the Kubernetes plugin: resolve `svc.cluster.local` names by watching the API |
| `kubeconfig /etc/kubernetes/coredns.conf` | Authenticate to the API server using a kubeconfig file (since CoreDNS runs outside the cluster) |
| `forward . /etc/resolv.conf` | Forward non-cluster queries (e.g., google.com) to the node's upstream DNS |
| `cache 30` | Cache DNS responses for 30 seconds |
| `loop` | Detect and stop forwarding loops |
| `reload` | Automatically reload the Corefile when it changes |
| `loadbalance` | Randomize the order of A records in responses (round-robin) |

> **Note** 💡 The `kubeconfig` option in the Kubernetes plugin is what makes this work outside the cluster. When CoreDNS runs as a Pod (the standard setup), it uses the ServiceAccount token mounted inside the container. When it runs as a systemd service, it needs a kubeconfig file with client certificates instead.

📌 *Start playground to activate this check*

Download the systemd unit file for CoreDNS:

```bash
sudo wget -O /etc/systemd/system/coredns.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/04-cluster/04-coredns/__static__/coredns.service?v=1777378804
```

The systemd unit file runs CoreDNS as the `coredns` user with the minimum required capabilities. `CAP_NET_BIND_SERVICE` allows it to listen on port 53 without running as root.

The service depends on `kube-apiserver` and restarts automatically on failure.

📌 *Start playground to activate this check*

Reload the systemd daemon and start the CoreDNS service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now coredns
```

📌 *Start playground to activate this check*

---

## Verifying DNS

Now try reaching the `podinfo` Service by name from the client Pod again:

```bash
kubectl exec client -- curl -fsS --max-time 5 "http://podinfo:80"
```

📌 *Start playground to activate this check*

It works. The client Pod resolved `podinfo` to the Service's ClusterIP through CoreDNS, and kube-proxy routed the traffic to one of the backend Pods.

Try the other name forms:

```bash
# Namespace-qualified
kubectl exec client -- curl -fsS --max-time 5 "http://podinfo.default:80"

# With svc prefix
kubectl exec client -- curl -fsS --max-time 5 "http://podinfo.default.svc:80"

# Fully qualified domain name
kubectl exec client -- curl -fsS --max-time 5 "http://podinfo.default.svc.cluster.local:80"
```

All four forms resolve to the same ClusterIP. The shorter forms work because of the search domains in `/etc/resolv.conf` that kubelet configured.

---

## The Full Picture

Here's what happens when the client Pod runs `curl http://podinfo:80`:

1. The client Pod's resolver reads `/etc/resolv.conf` and appends the first search domain: `.default.svc.cluster.local`
2. It sends a DNS query to `172.16.0.2` (the control-plane machine's IP from `clusterDNS`)
3. The packet is routed to the control-plane machine over the network
4. CoreDNS (running as a systemd service) receives the query and looks up the `podinfo` Service via the Kubernetes API
5. CoreDNS returns the Service's ClusterIP (e.g., `10.96.23.42`)
6. The client Pod connects to `10.96.23.42:80`
7. kube-proxy intercepts the packet (via iptables DNAT) and routes it to one of the `podinfo` backend Pods
8. The request reaches the Pod, and the response travels back the same path

Every networking component you installed across this module played a role: Flannel for the pod network, kube-proxy for Service routing, and CoreDNS for name resolution.

---

## 📚 Lesson Recap

In this lesson, you installed CoreDNS and completed the cluster's networking stack.

### Key Takeaways

- **Pod IPs are ephemeral, ClusterIPs are stable, but names are practical**: DNS is the final layer that makes service communication natural. Client Pods connect to `podinfo` instead of `10.96.23.42`
- **kubelet configures Pod DNS**: the `clusterDNS` and `clusterDomain` settings tell kubelet what to write into each Pod's `/etc/resolv.conf`. In this course, `clusterDNS` points directly at the control-plane machine's IP where CoreDNS is listening. In standard distributions, it typically points at a Service ClusterIP like `10.96.0.10`
- **CoreDNS watches the Kubernetes API** for Services and Endpoints, then answers DNS queries with the correct ClusterIPs. In this course, it runs on the control-plane machine as a systemd service, authenticating to the API server via a kubeconfig file with client certificates
- **The naming convention `<service>.<namespace>.svc.<cluster-domain>`** is predictable and hierarchical. Search domains in `/etc/resolv.conf` let Pods use short names like `podinfo` within the same namespace

With CoreDNS running, your cluster now has a complete networking stack:

| Layer | Component | What it does |
|-------|-----------|--------------|
| pod network | Flannel (CNI) | Gives Pods IP addresses and enables cross-node communication |
| Service network | kube-proxy (iptables) | Routes ClusterIP traffic to backend Pods with load balancing |
| DNS | CoreDNS | Resolves Service names to ClusterIPs |

Congratulations! You've assembled a fully functional Kubernetes cluster from the ground up. Every component, from etcd and the API server to kubelet, Flannel, kube-proxy, and CoreDNS, was installed and configured by hand as a systemd service.

You now understand not just how to use Kubernetes, but why each piece exists and what happens when it's missing.

---

## 📖 Additional Resources

- https://coredns.io/
- https://coredns.io/plugins/kubernetes/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config
- https://kubespec.dev/kubernetes/rbac.authorization.k8s.io/v1/ClusterRole
- https://kubespec.dev/kubernetes/rbac.authorization.k8s.io/v1/ClusterRoleBinding
