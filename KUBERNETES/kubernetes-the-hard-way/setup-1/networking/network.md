# Cluster Networking: Connecting Pods Across Nodes

In this lesson, you'll set up networking for your Kubernetes cluster, enabling Pods to communicate with each other.

## 📋 Objectives

- Understand the Kubernetes networking model and its requirements
- Diagnose why a node is NotReady after joining the cluster
- Learn what CNI (Container Network Interface) is, and how it operates at the node level
- Configure a bridge network using CNI so Pods on the same node can communicate
- Install a network addon to enable multi-node cluster networking

By the end of this lesson, you'll have a fully networked Kubernetes cluster where Pods can reach each other.

---

In the previous lesson, you joined a worker node to the control plane and deployed a workload. The Pod ran with `hostNetwork: true`, meaning it shared the host's network namespace and IP address.

That was a shortcut. In a real cluster, Pods get their own IP addresses and need to communicate with each other across the cluster, often running on different nodes entirely.

Kubernetes has a specific networking model that makes this possible. It defines the outcome (how Pods are addressed and how they communicate), but it doesn't prescribe the mechanism. Instead, it delegates the actual implementation to other layers.

## Requirements

The Kubernetes networking model has three fundamental rules:

1. Every Pod gets its own IP address - no sharing, no port conflicts between Pods
2. Pods can communicate with each other directly using their IP addresses, without NAT
3. The IP a Pod sees for itself is the same IP other Pods use to reach it - no address translation tricks

Without these guarantees, every application would need to know which port it got assigned, which host it's running on, and how to reach other services through layers of NAT.

The Kubernetes model eliminates all of that. Applications can bind to well-known ports, discover each other more easily, and communicate as if they were all on the same flat network.

This is what makes Kubernetes networking feel "transparent" to applications.

## Implementation

Kubernetes itself does not wire pod networking. Instead, it delegates that work to the container runtime. In this setup, containerd uses CNI (Container Network Interface) plugins to configure Pod interfaces, IP addresses, and routes on each node.

But a Kubernetes cluster rarely runs on a single node (at least not in production). If Pods on different nodes need to communicate, something also has to coordinate subnet allocation and cross-node connectivity across the cluster.

## Two Layers of the Problem

The Kubernetes model itself doesn't distinguish between "same-node" and "cross-node" networking. That's an implementation detail that varies across different networking solutions.

However, making that distinction is useful in this lesson because it helps separate two concerns:

| Layer | What it solves |
|-------|----------------|
| Node-level setup | Giving Pods interfaces, IPs, and local connectivity on one node |
| Cluster-level coordination | Making cluster networking work across multiple nodes |

You'll configure both in this lesson.

---

> **⚠️ Run the commands in this section on the control-plane machine.**

The playground started a cluster with two worker Nodes: `worker-1` and `worker-2`. Both have joined the cluster through the TLS bootstrap process you configured in the previous lesson.

Check the node status:

```bash
kubectl get nodes
```

Both nodes show `NotReady`. This is the same problem you saw briefly at the end of the previous lesson, but this time you'll fix it properly instead of applying a workaround.

Look at why `worker-1` is not ready:

```bash
kubectl describe node worker-1
```

In the `Conditions` section, you should see something like:

```
container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
```

`kubelet` is running. The node is registered. But the container runtime (containerd) is reporting that the network isn't ready because there's no CNI configuration.

## What is CNI?

CNI (Container Network Interface) is a specification that defines how container runtimes set up networking for containers.

You already encountered CNI in the containerd lesson where you installed the reference CNI plugins on the worker node.

But having the plugins installed is not enough. containerd also needs to know which CNI plugins to use and how to configure them. This is done through CNI configuration files stored in `/etc/cni/net.d/`.

This is how containerd uses CNI when a Pod starts:

1. A Pod gets scheduled to a node
2. `kubelet` tells containerd to create the Pod's sandbox (that includes a network namespace)
3. containerd looks for CNI configuration files in `/etc/cni/net.d/`
4. containerd runs the configured CNI plugin, passing it the configuration
5. The plugin sets up networking for that Pod (creates interfaces, assigns IPs, configures routes, and so on)

In other words, a CNI "plugin" is not a Kubernetes object or a long-running daemon. It's just an executable (by convention in `/opt/cni/bin/`) that the runtime calls with a JSON configuration and a few environment variables describing the operation.

The runtime invokes CNI on the node where the Pod is being created, and the plugin configures networking for that Pod on that node.

Right now, step 3 fails because `/etc/cni/net.d/` is empty. containerd reports `NetworkPluginNotReady` to `kubelet`, which in turn reports the node as `NotReady`.

---

> **⚠️ Run the commands in this section on the worker-1 machine (unless indicated otherwise).**

To make the node Ready, you need to give containerd a working CNI configuration.

Start with the `bridge` plugin to demonstrate node-level pod networking. It lets Pods on the same node communicate through a shared bridge.

## Creating the CNI Configuration

The `bridge` plugin creates a virtual network bridge on the node. It connects each Pod to that bridge using a veth pair: one end stays in the Pod's network namespace, the other end is attached to the bridge.

Create the bridge configuration:

**/etc/cni/net.d/10-bridge.conf**

```bash
cat <<EOF > /etc/cni/net.d/10-bridge.conf
{
  "cniVersion": "1.0.0",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.0.0/24",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
EOF
```

```bash
sudoedit /etc/cni/net.d/10-bridge.conf
```

| Field | Purpose |
|-------|---------|
| `type: bridge` | Use the bridge CNI plugin binary from `/opt/cni/bin/` |
| `bridge: cni0` | Name of the Linux bridge device to create |
| `isGateway: true` | Assign an IP to the bridge so it can act as a gateway for Pods |
| `ipMasq: true` | Enable IP masquerading (SNAT) so traffic leaving the pod subnet can reach the node network |
| `ipam.type: host-local` | Use the host-local IPAM plugin to manage IP addresses from a local pool |
| `ipam.subnet: 10.244.0.0/24` | The subnet to allocate Pod IPs from on this node |
| `ipam.routes` | Add a default route inside each Pod so all non-local traffic goes through the bridge gateway (the bridge gets an IP because `isGateway` is true) |

📌 *Start playground to activate this check*

> **Note** 💡 Each node needs its own subnet so that Pod IPs are unique across the cluster.  
> `worker-1` uses `10.244.0.0/24`, and later you'll configure `worker-2` with `10.244.1.0/24`.

![alt text](image-14.png)

Flannel was one of the first network addons for Kubernetes, even predating CNI. It was widely adopted because it was simple, so its default `10.244.0.0/16` subnet range stuck around.

Kubernetes doesn't require this exact subnet range. Other network addons may use different ranges as defaults.

You also need a loopback configuration so that Pods can communicate with themselves on `127.0.0.1`:

**/etc/cni/net.d/99-loopback.conf**

```bash
cat <<EOF>/etc/cni/net.d/99-loopback.conf
{
  "cniVersion": "1.0.0",
  "name": "lo",
  "type": "loopback"
}
EOF
```

```bash
sudoedit /etc/cni/net.d/99-loopback.conf
```

📌 *Start playground to activate this check*

## Verifying the Node is Ready

> **Important** ⚠️ Switch to the control-plane machine.

containerd picks up CNI configuration changes automatically. Within a few seconds, the node should become Ready:

```bash
kubectl wait --for=condition=Ready node worker-1
kubectl get nodes
```

📌 *Start playground to activate this check*

The node is now Ready because containerd can set up pod networking using the `bridge` plugin.

At this point, you've solved the node-level part of the problem for `worker-1`.

## Same-Node Pod Communication

With CNI configured, Pods on `worker-1` can get IP addresses and talk to each other.

Deploy two Pods on `worker-1` to test connectivity:

- `podinfo-worker-1` runs the usual podinfo web app
- `client-worker-1` is a tiny curl-based client that will talk to `podinfo-worker-1` over the Pod network

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: podinfo-worker-1
spec:
  nodeName: worker-1
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
      ports:
        - containerPort: 9898

---
apiVersion: v1
kind: Pod
metadata:
  name: client-worker-1
spec:
  nodeName: worker-1
  containers:
    - name: curl
      image: ghcr.io/stefanprodan/podinfo:latest
      command: ["sh", "-c", "sleep infinity"]
EOF
```

> **Note** 💡 Notice `nodeName: worker-1` in both Pod specs.  
> This bypasses the scheduler and places both Pods directly on `worker-1`. Normally you wouldn't do this, but it's useful for testing same-node networking explicitly.

> **Note** 💡 Also notice that there is no more `hostNetwork: true`.  
> Each Pod now gets its own network namespace and its own Pod IP, so this test exercises the CNI setup you just created instead of piggybacking on the node network.

Wait for both Pods to start:

```bash
kubectl wait --for=condition=Ready pod podinfo-worker-1 client-worker-1
kubectl get pods -o wide
```

📌 *Start playground to activate this check*

Both Pods should have IPs from the `10.244.0.0/24` subnet. Verify that they can communicate:

```bash
PODINFO_IP=$(kubectl get pod podinfo-worker-1 -o jsonpath='{.status.podIP}')

kubectl exec client-worker-1 -- curl -fsS "http://${PODINFO_IP}:9898/version"
```

📌 *Start playground to activate this check*

You should see a JSON response from `podinfo-worker-1`. The two Pods are communicating through the `cni0` bridge on `worker-1`, each using their own IP address.

## What Happens Behind the Scenes?

> **Important** ⚠️ Switch to the `worker-1` machine.

To see how this works in practice, let's inspect the routing table:

```bash
ip route show
```

You should see something like this:

```
default via 172.16.0.1 dev eth0
10.244.0.0/24 dev cni0 proto kernel scope link src 10.244.0.1
172.16.0.0/24 dev eth0 proto kernel scope link src 172.16.0.3
```

That tells us `worker-1` knows the entire `10.244.0.0/24` subnet is directly reachable through the `cni0` bridge.

So when `client-worker-1` sends traffic to `podinfo-worker-1`, the packet stays on the same node:

- It leaves the client Pod over its veth interface
- It reaches the `cni0` bridge on `worker-1`
- Then it's forwarded to the veth attached to `podinfo-worker-1`

No overlay, no inter-node routing, no tunnel. Just local bridge forwarding.

This is one way to implement the Kubernetes networking model on a single node.

But what about Pods on different nodes?

---

> **Important** ⚠️ Run the commands in this section on the `worker-2` machine (unless indicated otherwise).

`worker-2` is still `NotReady` because it has no CNI configuration either.

Configure it with the same `bridge` + `loopback` setup, but using a different subnet (`10.244.1.0/24`):

**/etc/cni/net.d/10-bridge.conf**

```bash
cat <<EOF > /etc/cni/net.d/10-bridge.conf
{
  "cniVersion": "1.0.0",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.1.0/24",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
EOF
```

```bash
sudoedit /etc/cni/net.d/10-bridge.conf
```

**/etc/cni/net.d/99-loopback.conf**

```bash
cat <<EOF > /etc/cni/net.d/99-loopback.conf
{
  "cniVersion": "1.0.0",
  "name": "lo",
  "type": "loopback"
}
EOF
```

```bash
sudoedit /etc/cni/net.d/99-loopback.conf
```

📌 *Start playground to activate this check*

> **Important** ⚠️ Switch to the control-plane machine.

Wait for `worker-2` to become Ready:

```bash
kubectl wait --for=condition=Ready node worker-2
kubectl get nodes
```

📌 *Start playground to activate this check*

Both nodes are now Ready.

That means containerd can set up cluster networking on both nodes which should (in theory) allow Pods to communicate across nodes.

## Testing Cross-Node Communication

Create the cross-node test Pod on `worker-2`:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: podinfo-worker-2
spec:
  nodeName: worker-2
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
      ports:
        - containerPort: 9898
EOF
```

Wait for the Pod to start:

```bash
kubectl wait --for=condition=Ready pod podinfo-worker-2
kubectl get pods -o wide
```

📌 *Start playground to activate this check*

Notice the IP addresses: `client-worker-1` and `podinfo-worker-1` have IP from `10.244.0.0/24`, while `podinfo-worker-2` has one from `10.244.1.0/24`.

Now run the cross-node connectivity check from `client-worker-1`:

```bash
PODINFO_IP=$(kubectl get pod podinfo-worker-2 -o jsonpath='{.status.podIP}')

kubectl exec client-worker-1 -- curl -fsS --max-time 5 "http://${PODINFO_IP}:9898/version"
```

> **Note** 💡 Even though you're running `kubectl exec` on the control-plane machine, the curl process runs inside `client-worker-1`.  
> So the actual traffic path is still Pod-to-Pod: from `worker-1` to `worker-2`.

> **Important** ⚠️ This will fail (timeout after 5 seconds). Cross-node traffic doesn't work yet.

## Why Cross-Node Traffic Fails

> **Important** ⚠️ Switch to the `worker-1` machine.

Inspect the routing table again to understand why cross-node traffic fails:

```bash
ip route show
```

You'll still see a connected route for `10.244.0.0/24` via `cni0`, but there is no route for `10.244.1.0/24`.

That's the key difference from the same-node case. `worker-1` knows how to reach Pods on its own bridge, but it has no idea where to send traffic for the pod subnet living on `worker-2`.

Each node has its own `cni0` bridge with its own subnet:

| Node | Bridge | Subnet |
|------|--------|--------|
| worker-1 | cni0 | 10.244.0.0/24 |
| worker-2 | cni0 | 10.244.1.0/24 |

When `client-worker-1` (10.244.0.x) tries to reach `podinfo-worker-2` (10.244.1.x), the packet leaves the Pod, hits the `cni0` bridge on `worker-1`, and gets forwarded to the node's default gateway.

But the node doesn't know how to route 10.244.1.0/24 traffic. That subnet only exists on `worker-2`'s bridge, and no one has told `worker-1` how to get there.

![alt text](image-15.png)

No route to 10.244.1.0/24 via cni0

The `bridge` CNI plugin has no concept of other nodes or their subnets. Something else needs to handle that.

## A Manual Routing Experiment

Before reaching for the proper solution, let's prove that this really is a routing problem.

If each worker knew how to reach the other worker's pod subnet, cross-node pod traffic would work. We can demonstrate that by adding routes manually.

First, find the node IP addresses on the worker network.

Switch to `worker-1`:

```bash
ip -4 addr show dev eth0
```

Switch to `worker-2`:

```bash
ip -4 addr show dev eth0
```

You should see addresses from the playground network, for example:

- worker-1: 172.16.0.3
- worker-2: 172.16.0.4

Now add routes for the remote pod subnet on both workers.

Switch to `worker-1`:

```bash
sudo ip route add 10.244.1.0/24 via 172.16.0.4
ip route show
```

📌 *Start playground to activate this check*

Expected output:

```
default via 172.16.0.1 dev eth0
10.244.0.0/24 dev cni0 proto kernel scope link src 10.244.0.1
10.244.1.0/24 via 172.16.0.4 dev eth0
172.16.0.0/24 dev eth0 proto kernel scope link src 172.16.0.3
```

Switch to `worker-2`:

```bash
sudo ip route add 10.244.0.0/24 via 172.16.0.3
ip route show
```

📌 *Start playground to activate this check*

Expected output:

```
default via 172.16.0.1 dev eth0
10.244.1.0/24 dev cni0 proto kernel scope link src 10.244.1.1
10.244.0.0/24 via 172.16.0.3 dev eth0
172.16.0.0/24 dev eth0 proto kernel scope link src 172.16.0.4
```

Now switch back to the control-plane and try the same request again (this time it should work):

```bash
PODINFO_IP=$(kubectl get pod podinfo-worker-2 -o jsonpath='{.status.podIP}')

kubectl exec client-worker-1 -- curl -fsS "http://${PODINFO_IP}:9898/version"
```

📌 *Start playground to activate this check*

You've just proven that the missing piece was cluster-wide routing information.

> **Note** 💡 This setup works as a demonstration, but it does not scale.  
> Every node would need routes for every other node's pod subnet, and someone would need to keep those routes up to date as nodes join, leave, or change.

You've proven that cross-node cluster networking is fundamentally a routing problem. Now you'll replace the manual setup with Flannel, which handles this automatically.

---

To start with a clean slate, remove everything:

- the test Pods, the static routes,
- the CNI config files
- and the bridge device along with its IPAM state (the IP allocations tracked in `/var/lib/cni/`)

> **Important** ⚠️ Switch to the control-plane machine.

Delete all Pods from the previous tests:

```bash
kubectl delete pod --all
for pod in podinfo-worker-1 client-worker-1 podinfo-worker-2; do
  kubectl wait --for=delete pod $pod
done
```

📌 *Start playground to activate this check*

> **Important** ⚠️ Switch to the `worker-1` machine.

Remove the manual route:

```bash
sudo ip route del 10.244.1.0/24 via 172.16.0.4
```

📌 *Start playground to activate this check*

Remove the CNI configuration:

```bash
sudo rm -f /etc/cni/net.d/10-bridge.conf /etc/cni/net.d/99-loopback.conf
```

📌 *Start playground to activate this check*

Remove the network configuration and interface:

```bash
sudo ip link delete cni0 || true
sudo rm -rf /var/lib/cni/networks/bridge /var/lib/cni/networks/cbr0
```

📌 *Start playground to activate this check*

> **Important** ⚠️ Switch to the `worker-2` machine.

Remove the manual route:

```bash
sudo ip route del 10.244.0.0/24 via 172.16.0.3
```

📌 *Start playground to activate this check*

Remove the CNI configuration:

```bash
sudo rm -f /etc/cni/net.d/10-bridge.conf /etc/cni/net.d/99-loopback.conf
```

📌 *Start playground to activate this check*

Remove the network configuration and interface:

```bash
sudo ip link delete cni0 || true
sudo rm -rf /var/lib/cni/networks/bridge /var/lib/cni/networks/cbr0
```

---

## Network Addon

A network addon is the missing piece that makes cluster networking work across nodes.

Unlike the `bridge` CNI config you created manually on each node, a network addon adds the cluster-level coordination that node-level CNI setup alone does not provide. It coordinates subnet allocation, routing, and tunnel setup across the whole cluster.

How it achieves that is entirely up to the implementation. Some distribute routes directly, for example with BGP, essentially automating what you did manually with `ip route add`. Others use overlay networks such as VXLAN, which work even when the underlying network doesn't allow direct routing between pod subnets, making them more portable across different infrastructure.

An overlay network creates a virtual network on top of the existing physical network. When a Pod on `worker-1` sends a packet to a Pod on `worker-2`, the overlay encapsulates the packet (wraps it in another packet) and sends it over the regular node-to-node network.

The receiving node unwraps it and delivers it to the destination Pod. This way, Pods can communicate as if they're on the same network, even though they're on different machines.

VXLAN is a common encapsulation protocol used by network addons like Flannel.

![alt text](image-16.png)

In many modern clusters, that coordination logic usually runs inside Kubernetes (for example, as DaemonSets).

Here you'll do it the hard-way and run it as a systemd service on each worker.

Network addons typically:

- Deploy or manage CNI configuration on each node (replacing any manual config)
- Set up an overlay network or configure routes so Pods on different nodes can communicate
- Manage IPAM (IP Address Management) across the cluster to ensure Pod IPs are unique

## Flannel

You'll use Flannel in this lesson, one of the oldest and simplest network addons out there.

> **Note** 💡 These days you rarely find Flannel in production clusters, but it's perfect for the purposes of this lesson.

Flannel (like many other network addons) consists of two components:

- A daemon that runs on each node and handles the cluster-level coordination
- A CNI plugin that configures pod networking

In this setup, Flannel works by:

- Using the per-node Pod CIDR allocated from the cluster-wide CIDR (here, `10.244.0.0/16`)
- Running `flanneld` as a systemd service on each worker to watch those node subnet assignments (via the Kubernetes API)
- Installing a Flannel CNI configuration so containerd can delegate pod networking to the flannel plugin
- Setting up a VXLAN overlay so traffic between subnets on different nodes gets tunneled across the network

The split is the same one you've seen throughout this lesson:

- **Node-level setup**: containerd invokes the CNI plugin to wire a Pod into the local network on its node
- **Cluster-level coordination**: Flannel makes those node-local pod networks work together across the cluster

## Where do Pod CIDRs Come From?

> **Important** ⚠️ Switch to the control-plane machine.

Back in the `kube-controller-manager` lesson, the controller manager was configured with the following flags:

```
--cluster-cidr=10.244.0.0/16
--allocate-node-cidrs=true
```

Together, they tell the controller manager to use the `10.244.0.0/16` CIDR block for cluster networking, and to carve that block into per-node Pod CIDRs and assign them to Nodes.

You can inspect that now:

```bash
kubectl get node worker-1 -o jsonpath='{.spec.podCIDR}{"\n"}'
kubectl get node worker-2 -o jsonpath='{.spec.podCIDR}{"\n"}'
```

You should see something like:

- worker-1: `10.244.0.0/24`
- worker-2: `10.244.1.0/24`

> **Note** 💡 `kube-controller-manager` uses /24 node subnets by default in setups like this.  
> You can change the size of the per-node subnet with the `--node-cidr-mask-size` flag.

This metadata does not configure pod networking by itself. Your manual bridge setup earlier worked because you wrote the subnet directly into the local CNI configuration.

What changes here is that Flannel can read the Pod CIDRs Kubernetes assigned to each node, use them to configure Pod IP allocation, and set up routing between nodes accordingly.

## Prerequisites for Flannel

Flannel uses the Kubernetes API to coordinate node subnet assignments, so it needs access to the API server. The process of configuring it is the same as for control plane components in previous lessons. The difference is you will have to copy the kubeconfig to each worker node.

Flannel gets its own certificate and identity (`system:flannel`) so its API access can be scoped to only the permissions it needs.

Generate a certificate and key for Flannel:

```bash
(
cd /etc/kubernetes/pki

sudo openssl genrsa -out flannel.key 2048
sudo openssl req -new -key flannel.key -out flannel.csr -subj "/CN=system:flannel"
sudo openssl x509 -req -in flannel.csr -out flannel.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
)
```

📌 *Start playground to activate this check*

Create a kubeconfig for Flannel:

```bash
sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/flannel.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://control-plane:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/flannel.conf \
    --client-certificate=/etc/kubernetes/pki/flannel.crt \
    --client-key=/etc/kubernetes/pki/flannel.key \
    --embed-certs=true

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/flannel.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/flannel.conf
```

📌 *Start playground to activate this check*

Configure RBAC:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:flannel
rules:
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:flannel
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: system:flannel
EOF
```

📌 *Start playground to activate this check*

This prepares the cluster-side pieces Flannel needs:

- Generates a client certificate and kubeconfig for the `system:flannel` identity
- Configures RBAC that lets Flannel read node information and update node status

## Installing Flannel on worker-1

> **Important** ⚠️ Switch to the `worker-1` machine.

Download and install Flannel on `worker-1`:

```bash
FLANNEL_VERSION=v0.27.2
FLANNEL_PLUGIN_VERSION=v1.7.1-flannel2

curl -fsSLO "https://github.com/flannel-io/flannel/releases/download/${FLANNEL_VERSION?}/flannel-${FLANNEL_VERSION?}-linux-amd64.tar.gz"
curl -fsSLO "https://github.com/flannel-io/cni-plugin/releases/download/${FLANNEL_PLUGIN_VERSION?}/cni-plugin-flannel-linux-amd64-${FLANNEL_PLUGIN_VERSION?}.tgz"

tar xzvof "flannel-${FLANNEL_VERSION?}-linux-amd64.tar.gz"
tar xzvof "cni-plugin-flannel-linux-amd64-${FLANNEL_PLUGIN_VERSION?}.tgz"

sudo install -m 755 flanneld /usr/local/bin
sudo install -m 755 flannel-amd64 /opt/cni/bin/flannel
```

📌 *Start playground to activate this check*

Download the systemd unit file for `flanneld`:

```bash
sudo wget -O /etc/systemd/system/flanneld.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/04-cluster/02-network/__static__/flanneld.service?v=1777378798
```

📌 *Start playground to activate this check*

| Flag / Setting | Purpose |
|----------------|---------|
| `--kube-subnet-mgr` | Read pod subnet assignments from the Kubernetes API (via Node `.spec.podCIDR`) instead of a local etcd instance |
| `--kube-api-url` | The API server endpoint to connect to |
| `--kubeconfig-file` | Path to the kubeconfig with Flannel's client certificate |
| `--ip-masq` | Set up IP masquerading (SNAT) for traffic leaving the cluster pod network |
| `--net-config-path` | Path to the network configuration file (`net-conf.json`) |
| `NODE_NAME=%H` | Tells Flannel which node it's running on. When Flannel runs as a Pod, it gets this from the Kubernetes downward API. As a systemd service, `%H` (the hostname) provides it instead |

Configure Flannel to use the correct CIDR range:

**/etc/flannel/net-conf.json**

```bash
cat <<EOF > /etc/flannel/net-conf.json
{
    "Network": "10.244.0.0/16",
    "EnableNFTables": false,
    "Backend": {
        "Type": "vxlan"
    }
}
EOF
```

```bash
sudo mkdir -p /etc/flannel
sudoedit /etc/flannel/net-conf.json
```

> **Note** 💡 `EnableNFTables` is set to `false` because this environment uses iptables.  
> Flannel defaults to nftables on newer systems, which would conflict.

Configure the Flannel CNI plugin:

**/etc/cni/net.d/10-flannel.conflist**

```bash
cat <<EOF >/etc/cni/net.d/10-flannel.conflist
{
  "name": "cbr0",
  "cniVersion": "1.0.0",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}
EOF
```

```bash
sudoedit /etc/cni/net.d/10-flannel.conflist
```

Under the hood, the Flannel CNI plugin delegates to the same `bridge` plugin you configured manually earlier. The difference is that Flannel supplies the subnet automatically based on the node's Pod CIDR assignment.

You also don't need a separate `99-loopback.conf` anymore. When using a `conflist`, containerd configures the loopback interface in the Pod's network namespace automatically.

| Field | Purpose |
|-------|---------|
| `name: cbr0` | Logical network name, used by CNI for tracking IPAM state |
| `type: flannel` | The Flannel CNI plugin. It reads the node's subnet assignment from `flanneld`, then delegates to a bridge plugin under the hood |
| `delegate.hairpinMode` | Allows a Pod to reach itself through its own Service IP |
| `delegate.isDefaultGateway` | Makes the bridge the default gateway for Pods (same role as `isGateway` in the manual bridge config) |
| `type: portmap` | Enables `hostPort` mappings for containers |

Notice that this is a `conflist` (a chain of plugins), not a single plugin config like the `bridge` file you created earlier. The `flannel` plugin handles the bridge and IPAM setup internally, and then `portmap` runs after it.

📌 *Start playground to activate this check*

Copy the kubeconfig file to the worker:

```bash
sudo scp control-plane:/etc/kubernetes/flannel.conf /etc/kubernetes/flannel.conf
```

📌 *Start playground to activate this check*

Reload the systemd daemon and start the `flanneld` service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now flanneld
```

📌 *Start playground to activate this check*

Before installing Flannel on `worker-2`, let's make sure same-node networking is still working.

> **Important** ⚠️ Switch to the control-plane machine.

Recreate the test Pods for same-node connectivity:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: podinfo-worker-1
spec:
  nodeName: worker-1
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
      ports:
        - containerPort: 9898

---
apiVersion: v1
kind: Pod
metadata:
  name: client-worker-1
spec:
  nodeName: worker-1
  containers:
    - name: curl
      image: ghcr.io/stefanprodan/podinfo:latest
      command: ["sh", "-c", "sleep infinity"]
EOF
```

Wait for both Pods to start:

```bash
kubectl wait --for=condition=Ready pod podinfo-worker-1 client-worker-1
kubectl get pods -o wide
```

📌 *Start playground to activate this check*

Verify that they can communicate:

```bash
PODINFO_IP=$(kubectl get pod podinfo-worker-1 -o jsonpath='{.status.podIP}')

kubectl exec client-worker-1 -- curl -fsS "http://${PODINFO_IP}:9898/version"
```

📌 *Start playground to activate this check*

> **Important** ⚠️ Switch to the `worker-1` machine.

One last thing to check before moving on to `worker-2` is the route table again:

```bash
ip route show
```

You should see something like this:

```
default via 172.16.0.1 dev eth0
10.244.0.0/24 dev cni0 proto kernel scope link src 10.244.0.1
172.16.0.0/24 dev eth0 proto kernel scope link src 172.16.0.3
```

Flannel recreated the `cni0` interface using the same `bridge` plugin that you used earlier.

There's no Flannel interface yet because there's only one worker node. The VXLAN (`flannel.1`) interface exists to tunnel pod traffic between nodes: with no second node, there's nothing to tunnel to.

## Installing Flannel on worker-2

> **Important** ⚠️ Switch to the `worker-2` machine.

Repeat the same steps you performed on `worker-1`:

1. Download and install `flanneld` and the CNI plugin
2. Download the systemd unit file
3. Create `/etc/flannel/net-conf.json`
4. Create `/etc/cni/net.d/10-flannel.conflist`
5. Copy the kubeconfig from control-plane
6. Reload systemd and start `flanneld`

> **Note** 💡 All configuration files are identical across workers.  
> Unlike the manual bridge setup where each node needed a different subnet in its CNI config, Flannel reads the node's assigned Pod CIDR from Kubernetes automatically.

📌 *Start playground to activate this check*

📌 *Start playground to activate this check*

📌 *Start playground to activate this check*

📌 *Start playground to activate this check*

📌 *Start playground to activate this check*

## Verifying Cross-Node Connectivity

> **Important** ⚠️ Switch to the control-plane machine.

Recreate the cross-node test Pod on `worker-2`:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: podinfo-worker-2
spec:
  nodeName: worker-2
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
      ports:
        - containerPort: 9898
EOF
```

Wait for the test Pod to start:

```bash
kubectl wait --for=condition=Ready pod podinfo-worker-2
kubectl get pods -o wide
```

📌 *Start playground to activate this check*

Then run the cross-node connectivity check again:

```bash
PODINFO_IP=$(kubectl get pod podinfo-worker-2 -o jsonpath='{.status.podIP}')

kubectl exec client-worker-1 -- curl -fsS "http://${PODINFO_IP}:9898/version"
```

📌 *Start playground to activate this check*

This time it works. The same connectivity check that timed out before now returns a response.

Same-node traffic still works too, but now the node-level networking is managed through Flannel's CNI configuration rather than the manual `10-bridge.conf` you created earlier.

Flannel set up a VXLAN tunnel between the nodes: when `client-worker-1` sends a packet to `10.244.x.x` on `worker-2`, Flannel encapsulates it and forwards it over the node network. `worker-2`'s Flannel agent decapsulates the packet and delivers it to the destination Pod.

## VXLAN in Action

Switch to `worker-1` and inspect the routing table again:

```bash
ip route show
```

You should still see the local pod subnet on `cni0`, but now you should also see a route for `10.244.1.0/24` that points at `flannel.1`.

That gives us the full picture:

- Traffic for `10.244.0.0/24` stays local on `cni0`
- Traffic for `10.244.1.0/24` is sent through `flannel.1`
- Flannel encapsulates it and carries it across the node network to `worker-2`

If you go back to `worker-2`, you should see a similar routing table with a route for `10.244.0.0/24` pointing at `flannel.1`.

---

In this lesson, you configured networking for your Kubernetes cluster, going from `NotReady` nodes to fully functional cross-node Pod communication.

## Key Takeaways

- **The Kubernetes networking model is a contract**: every Pod gets its own IP address, Pods can communicate directly without NAT, and a Pod sees the same IP other Pods use to reach it. Kubernetes delegates the implementation to other layers
- **CNI (Container Network Interface) is a node-level mechanism** for configuring container networking. Container runtimes like containerd look for CNI configuration in `/etc/cni/net.d/` and invoke the corresponding plugin binaries from `/opt/cni/bin/`
- **Bridge CNI plugin** creates a virtual bridge on each node, giving Pods IP addresses and enabling local Pod-to-Pod communication on that node. But it has no awareness of other nodes or their subnets
- **Network addons like Flannel** add the cluster-level coordination needed for multi-node cluster networking by setting up overlays (like VXLAN) or distributing routes between nodes. In this lesson, Flannel runs as a host-level systemd service and works together with the Flannel CNI plugin
- **Without something to coordinate routing across nodes**, Pods on different nodes cannot reach each other, even though both nodes are Ready and Pods are Running. Manual static routes can work as a proof of concept, but a network addon automates this for the entire cluster

With networking in place, Pods can now communicate freely across the cluster. However, Pod IPs are ephemeral: every time a Pod is recreated, it gets a new IP.

The next lessons will address this with `kube-proxy` and CoreDNS, which provide stable networking abstractions on top of the pod network you just built.

---

## 📖 Additional Resources

💡 To learn more about the concepts covered in this lesson, check out the resources below.

### 📰 Articles
- [Mastering Container Networking](https://iximiuz.com/en/series/mastering-container-networking/)

### 🎓 Courses
- [Computer Networking Fundamentals](https://labs.iximiuz.com/courses/computer-networking-fundamentals)

### 📖 Tutorials
- [How Container Networking Works](https://labs.iximiuz.com/tutorials/container-networking-from-scratch)

- https://kubernetes.io/docs/concepts/cluster-administration/networking/
- https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- https://kubernetes.io/docs/concepts/services-networking/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
- https://www.cni.dev/docs/spec/
- https://www.cni.dev/plugins/current/
- https://github.com/flannel-io/flannel
- https://kubespec.dev/kubernetes/v1/Pod
- https://kubespec.dev/kubernetes/v1/Node
- https://kubespec.dev/kubernetes/rbac.authorization.k8s.io/v1/ClusterRole
- https://kubespec.dev/kubernetes/rbac.authorization.k8s.io/v1/ClusterRoleBinding
