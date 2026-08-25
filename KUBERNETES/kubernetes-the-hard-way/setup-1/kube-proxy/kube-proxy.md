# kube-proxy: Making Services Work

In this lesson, you'll install kube-proxy, the component that makes Kubernetes Services work.

## 📋 Objectives

- Understand why Pod IPs alone aren't enough for reliable communication
- Learn what Kubernetes Services are and how they provide stable endpoints
- See what happens when you create a Service without kube-proxy
- Install and configure kube-proxy on worker nodes
- Understand how kube-proxy translates Services into iptables rules
- Verify Service-based communication across the cluster

By the end of this lesson, you'll have working service networking, bringing your cluster one step closer to production readiness.

---

In the previous lesson, you set up cluster networking with Flannel. Pods can now reach each other using their IP addresses, regardless of which node they're running on.

Pod IPs, however, have a critical limitation: they are **ephemeral**.

Every time you deploy a new version, scale a workload, or a Pod gets rescheduled, new Pods come up with new IP addresses. If your frontend application connects to a backend at `10.244.x.x`, that address becomes invalid the moment the backend Pod is replaced.

> **Note** 💡 This is actually a feature: ephemeral IPs allow Pods to be disposable units that can be replaced, rescheduled, and scaled without ceremony.  
> But from the perspective of a client that needs to connect to a Pod, it's a headache.

And that's just one Pod. Consider an application with multiple replicas:

| Pod | IP | Node |
|-----|----|------|
| backend-abc12 | 10.244.0.2 | worker-1 |
| backend-def34 | 10.244.1.2 | worker-2 |
| backend-ghi56 | 10.244.0.3 | worker-1 |

Which IP should the frontend use? All three are valid targets. How does the frontend load balance between them? What happens when one Pod dies and a new one comes up with a different IP?

Hardcoding Pod IPs is clearly not the way to go.

You need a stable endpoint that abstracts away the individual Pods behind it.

![alt text](image-17.png)

## Services

A **Service** is a Kubernetes resource that provides a stable network identity for a set of Pods.

When you create a Service, Kubernetes assigns it a **ClusterIP**: a virtual IP address from a dedicated range (the service CIDR, e.g., `10.96.0.0/12`) that never changes for the lifetime of the Service.

![alt text](image-18.png)

| Concept | Address | Lifetime | Example |
|---------|---------|----------|---------|
| Pod IP | From the Pod CIDR | Tied to the Pod (ephemeral) | 10.244.0.2 |
| ClusterIP | From the service CIDR | Tied to the Service (stable) | 10.96.0.10 |

A Service uses a **label selector** to find its target Pods. The Kubernetes control plane continuously tracks which Pods match the selector and maintains a list of their current IPs in objects called **EndpointSlices**.

This means:

- Clients connect to the ClusterIP (which never changes)
- The ClusterIP routes to one of the Pod IPs (which may change at any time)
- When Pods scale up or down, the EndpointSlices update automatically

> **Note** 💡 Unlike a Pod IP, which is bound to a network interface, a ClusterIP is virtual: no Pod or container is behind it. It's purely a frontend that gets rewritten to one of the real Pod IPs.

Something needs to intercept packets destined for a ClusterIP and rewrite their destination to one of the real Pod IPs.

That "something" is **kube-proxy**.

---

## Before kube-proxy

> **⚠️ Run the commands in this section on the control-plane machine.**

The playground started a cluster with two worker nodes, Flannel installed, and both nodes Ready. Pod-to-Pod networking works, but there's no kube-proxy running yet.

Before installing kube-proxy, let's test what happens without it.

Create a Deployment with three replicas of podinfo:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  replicas: 3
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
EOF
```

Wait for the Pods to start:

```bash
kubectl wait --for=condition=Ready pod -l app=podinfo
kubectl get pods -o wide
```

📌 *Start playground to activate this check*

Notice each Pod has its own IP address.

Now create a Service that targets these Pods:

```bash
kubectl apply -f - <<EOF
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
EOF
```

📌 *Start playground to activate this check*

Check the Service:

```bash
kubectl get svc podinfo
```

The Service exists and has a ClusterIP assigned. Kubernetes also created EndpointSlice objects that track the Pod IPs matching the Service's selector:

```bash
kubectl get endpointslices -l kubernetes.io/service-name=podinfo
```

You should see the IPs of all three podinfo Pods listed in the EndpointSlice.

Everything looks correct.

Try reaching the Service from inside the cluster:

```bash
CLUSTER_IP=$(kubectl get svc podinfo -o jsonpath='{.spec.clusterIP}')

kubectl exec deploy/podinfo -- curl -fsS --max-time 5 "http://${CLUSTER_IP}:80"
```

> **Important** ⚠️ This will fail (timeout after 5 seconds). The ClusterIP is virtual and has no backing rules yet.

The ClusterIP is a virtual address that only means something if there are network rules routing traffic from that IP to the actual Pod IPs.

Right now, no such rules exist. The packet arrives at the node's network stack, nobody knows where to send it, and it gets dropped.

> **Note** 💡 This is similar to the cross-node problem from the network lesson. The Service object is just data in the API server. Without something to act on it, it's a phone number that nobody has wired up.

---

## What is kube-proxy?

**kube-proxy** is a network component that runs on every node and implements the Service abstraction by programming the node's packet filtering rules.

It follows the same controller pattern you've seen throughout this course:

1. Watch the API server for Service and EndpointSlice changes
2. Translate each Service into network rules that redirect ClusterIP traffic to real Pod IPs
3. Update the rules whenever Pods are added, removed, or rescheduled

kube-proxy's default mode uses **iptables** to implement these rules. When a packet arrives at a node destined for a ClusterIP, iptables matches it and rewrites the destination address to one of the Pod IPs in the EndpointSlices list. This happens entirely in the kernel's network stack, no userspace proxy involved.

kube-proxy supports multiple modes for programming network rules:

| Mode | Mechanism | Notes |
|------|-----------|-------|
| iptables | Linux iptables rules | Default. Reliable, well-understood. Can slow down with thousands of Services |
| ipvs | Linux IPVS (IP Virtual Server) | Better performance at scale. Requires IPVS kernel modules |
| nftables | Linux nftables rules | Newer alternative to iptables. Available since Kubernetes 1.31 |

All three modes achieve the same result: translating ClusterIP traffic into Pod IP traffic. They differ in performance characteristics and kernel requirements.

This lesson uses the default **iptables** mode.

> **Note** 💡 kube-proxy is technically optional. Some network addons (like Cilium) can replace kube-proxy entirely, implementing Service routing using eBPF or other mechanisms.  
> However, most clusters still use kube-proxy. It's the standard, well-tested solution that comes with Kubernetes out of the box.

---

## Prerequisites for kube-proxy

> **Important** ⚠️ Run the commands in this section on the control-plane machine (unless indicated otherwise).

Like every other component that talks to the API server, kube-proxy needs to authenticate with the API server.

Generate a certificate and key for kube-proxy:

```bash
(
cd /etc/kubernetes/pki

sudo openssl genrsa -out kube-proxy.key 2048
sudo openssl req -new -key kube-proxy.key -out kube-proxy.csr -subj "/CN=system:kube-proxy"
sudo openssl x509 -req -in kube-proxy.csr -out kube-proxy.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
)
```

📌 *Start playground to activate this check*

Create a kubeconfig for kube-proxy:

```bash
sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/kube-proxy.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://control-plane:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/kube-proxy.conf \
    --client-certificate=/etc/kubernetes/pki/kube-proxy.crt \
    --client-key=/etc/kubernetes/pki/kube-proxy.key \
    --embed-certs=true

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/kube-proxy.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/kube-proxy.conf
```

📌 *Start playground to activate this check*

---

## Installing kube-proxy

> **Important** ⚠️ Run the following steps on both `worker-1` and `worker-2`.

Download and install kube-proxy:

```bash
KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-proxy"

sudo install -m 755 kube-proxy /usr/local/bin
```

📌 *Start playground to activate this check*  
📌 *Start playground to activate this check*

Copy the kubeconfig from the control plane:

```bash
sudo scp control-plane:/etc/kubernetes/kube-proxy.conf /etc/kubernetes/kube-proxy.conf
```

📌 *Start playground to activate this check*  
📌 *Start playground to activate this check*

---

## Configuring kube-proxy

kube-proxy is configured through a `KubeProxyConfiguration` file. At minimum, it needs:

- The Pod CIDR range, the same value configured in the kube-controller-manager lesson (and in the previous one)
- Path to the kubeconfig file

Create the kube-proxy configuration file:

**/etc/kubernetes/kube-proxy/config.yaml**

```bash
cat <<EOF > /etc/kubernetes/kube-proxy/config.yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration

clusterCIDR: 10.244.0.0/16

clientConnection:
  kubeconfig: /etc/kubernetes/kube-proxy.conf
EOF
```

```bash
sudo mkdir -p /etc/kubernetes/kube-proxy
sudoedit /etc/kubernetes/kube-proxy/config.yaml
```

📌 *Start playground to activate this check*  
📌 *Start playground to activate this check*

Download the systemd unit file for kube-proxy:

```bash
sudo wget -O /etc/systemd/system/kube-proxy.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/04-cluster/03-kube-proxy/__static__/kube-proxy.service?v=1777378802
```

📌 *Start playground to activate this check*  
📌 *Start playground to activate this check*

Start kube-proxy:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kube-proxy
```

📌 *Start playground to activate this check*  
📌 *Start playground to activate this check*

---

## Testing the Service with kube-proxy

> **Important** ⚠️ Run the commands in this section on the control-plane machine.

Now try reaching the Service again:

```bash
CLUSTER_IP=$(kubectl get svc podinfo -o jsonpath='{.spec.clusterIP}')

kubectl exec deploy/podinfo -- curl -fsS "http://${CLUSTER_IP}:80"
```

📌 *Start playground to activate this check*

It works. The same ClusterIP that timed out before now returns a response from one of the podinfo Pods.

Run it a few more times:

```bash
for i in $(seq 1 5); do
    kubectl exec deploy/podinfo -- curl -fsS "http://${CLUSTER_IP}:80" | jq -r '.hostname'
done
```

You should see responses from different Pods. kube-proxy's iptables rules randomly distribute traffic across all healthy Pods, providing basic load balancing.

---

## What Happens Behind the Scenes?

> **Important** ⚠️ Switch to the `worker-1` or `worker-2` machine.

You can inspect the iptables rules that kube-proxy created:

```bash
sudo iptables -t nat -L KUBE-SERVICES -n | grep podinfo
```

This shows the rule chain for the `podinfo` Service. For every Service, kube-proxy creates a chain of iptables rules that:

- Match packets destined for the ClusterIP and port
- Select a random backend Pod (using the `--probability` flag for load balancing)
- DNAT (Destination NAT) the packet, rewriting the destination to the chosen Pod's IP and port

The result: from the application's perspective, it connects to a stable IP (ClusterIP:port), but the packet actually arrives at a real Pod. The rewriting happens in the kernel, transparently.

---

## 📚 Lesson Recap

In this lesson, you installed kube-proxy and brought Service-based networking to your Kubernetes cluster.

### Key Takeaways

- **Pod IPs are ephemeral**: they change with every Pod restart or reschedule. Applications need stable endpoints to communicate reliably, which is what Services provide
- **Services assign a stable ClusterIP** from the service CIDR. Kubernetes tracks which Pods match a Service's selector and maintains an EndpointSlice of their current IPs
- **ClusterIPs are virtual**: no network interface holds the address. Without something to program routing rules, traffic to a ClusterIP goes nowhere
- **kube-proxy watches Services and EndpointSlices**, then programs iptables rules on every node so that ClusterIP traffic is rewritten (DNAT) to a real Pod IP, with random load balancing across healthy backends
- **kube-proxy is optional**: some network addons like Cilium can replace kube-proxy entirely, implementing Service routing through eBPF or other mechanisms. But kube-proxy remains the standard, well-tested default

With kube-proxy running, your cluster now has two networking layers working together:

| Layer | Handles | Implemented by |
|-------|---------|----------------|
| Pod network | Pod-to-Pod communication using Pod IPs | CNI + Flannel |
| Service network | Stable endpoints with load balancing using ClusterIPs | kube-proxy (iptables) |

One piece is still missing: DNS. Clients still need to know the ClusterIP to reach a Service. The next lesson will set up CoreDNS so that Services can be discovered by name instead of IP.

---

## 📖 Additional Resources

- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/
- https://kubernetes.io/docs/reference/networking/virtual-ips/
- https://kubernetes.io/docs/tutorials/services/source-ip/
- https://kubernetes.io/docs/concepts/services-networking/service/#endpoints
- https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- https://linux.die.net/man/8/iptables
- https://kubespec.dev/kubernetes/v1/Service
- https://kubespec.dev/kubernetes/apps/v1/Deployment
- https://kubespec.dev/kubernetes/discovery.k8s.io/v1/EndpointSlice