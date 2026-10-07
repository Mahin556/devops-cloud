# Kubernetes Pod Networking & Flannel CNI — Detailed Notes

## 1. Kubernetes Networking Rules
Kubernetes imposes three key networking rules:

1. **All pods can communicate with each other on all nodes.**
   - Pod-to-pod communication must work cluster-wide, regardless of which node the pods are on.

2. **Agents on a node can communicate with all pods on that node.**
   - The transcript says “agents” means Kubernetes services, but in practice this also covers node-level components like kubelet and system daemons.

3. **No Network Address Translation (NAT).**
   - Each pod gets its own IP address.
   - That pod IP is used to address the pod directly from other pods or services.
   - No NAT is needed for pod-to-pod traffic.

**Rationale for these rules:**
- Simplicity.
- Hide implementation details.
- Enable service discovery.

---

## 2. Three Types of Networks in Kubernetes

### A. Node Network
- The network that connects Kubernetes nodes.
- Each node has its own IP address.
- IPs come from DHCP or, more commonly, static assignment.
- Nodes can communicate freely with each other and use shared resources on the same network.

### B. Pod Network
- Each pod gets its own IP address.
- Pods are addressable from anywhere in the cluster.
- Pod IPs are often allocated from an **IPAM pool / CIDR range** managed by the CNI plugin.
- Pods on the same node communicate through a bridge.
- Pods on different nodes communicate through an overlay network.

### C. Cluster Network
- Used by Kubernetes **Services**.
- Service IPs are allocated from the **service cluster IP range**.
- This range is configured in the API server and controller manager.
- There is a default range, but you can define your own.

---

## 3. Pod Networking Model

### Pods and Containers
- A pod can contain one or more containers.
- All containers in a pod **share a single IP address**.
- Containers inside the same pod communicate over **localhost**.
- Each pod has its own network namespace.

### Same-Node Pod Communication
- Pods on the same node normally communicate through a **bridge**.
- Depending on the CNI provider, iptables may also be used.
- The bridge is connected to the node’s network interface so pods can reach outside the node if needed.

### Cross-Node Pod Communication
- Pods on different nodes usually communicate through an **overlay network**.
- The overlay hides the complexity of the underlying network.
- It makes remote pods appear as if they are on the same local network.
- Common overlay technologies: VXLAN, IP-in-IP.

---

## 4. Container Network Interface (CNI)

### What Is CNI?
- CNI = **Container Network Interface**.
- An open-source project managed by the **Cloud Native Computing Foundation (CNCF)**.
- Provides specifications and libraries for writing plugins that configure network interfaces in Linux containers.
- Also provides a number of supported plugins.

### What CNI Does
- Handles **network connectivity** for containers.
- Removes allocated network resources when a container is deleted.
- Automates what was done manually in the previous video:
  - Creating network namespaces.
  - Creating veth pairs.
  - Creating bridges.
  - Setting up tunnels between nodes.

### CNI and Kubernetes
- Kubernetes does **not** manage pod networking itself.
- Pod networking is delegated to CNI plugins.
- You must install a CNI plugin when setting up Kubernetes.
- Common CNI plugins:
  - **Flannel** — oldest and simplest.
  - **Calico** — more advanced, often Layer 3.
- Other platforms that use CNI:
  - Cloud Foundry
  - Podman
  - CRI-O

---

## 5. Flannel CNI Deep Dive

### Overview
- Flannel is the **oldest and simplest** CNI plugin.
- Suitable for **small to medium-sized Kubernetes clusters**.
- Best when all nodes are on the **same subnet**.

### How Flannel Allocates IPs
- Flannel assigns a **block of IP addresses** to each node.
- Each node manages its own pod subnet.
- When a pod is created on a node, it gets an IP from that node’s block.

### Same-Node Pod Communication
- Pods on the same node are connected through a **Layer 2 bridge**.
- The bridge is typically `cni0`.

### Cross-Node Pod Communication
- By default, Flannel uses **VXLAN (Virtual Extensible LAN)** encapsulation.
- It wraps a Layer 2 Ethernet frame inside a UDP packet.
- This creates a **UDP tunnel** over the existing network.
- The tunnel interface is usually called `flannel.1`.

### Flannel Traffic Path
```text
Pod A on Node 1
  → cni0 bridge
  → flannel.1 interface
  → Node 1 physical NIC
  → VXLAN UDP tunnel (port 8472)
  → Node 2 physical NIC
  → flannel.1 interface
  → cni0 bridge
  → Pod B on Node 2
```

- Inside the VXLAN packet, the original Ethernet frame is encapsulated.
- That frame contains:
  - Destination IP
  - Source IP
  - Data
  - Other headers
- The remote node decapsulates the packet, determines the destination pod, and forwards it.

---

## 6. Demo: Verifying Flannel Networking

### Cluster Setup
- Two-node cluster: `master` and `node1`.
- CNI plugin: Flannel.
- Cluster runs inside Hyper-V.

### Verify veth Pairs
```bash
ip link show type veth
```
- Shows virtual Ethernet interfaces.
- They come in pairs.
- One end connects to the pod, the other to the bridge.

### Verify Bridges
```bash
ip link show type bridge
```
- Shows bridges on the node.
- The important one is `cni0`.
- `cni0` should be up.

### Verify Interfaces Attached to `cni0`
```bash
ip link show master cni0
```
- Shows which veth interfaces are attached to the CNI bridge.

### Verify Pod IPs
```bash
kubectl get pods -o wide
```
- Shows pod names, nodes, and IP addresses.
- Example: two pods on `node1` with IPs like `10.244.0.18` and `10.244.0.19`.

### Verify Routes
```bash
ip route
```
Example routes:
- `default via 192.168.0.1` — Hyper-V switch.
- `10.244.0.0/24 via flannel.1` — remote pod subnet.
- `10.244.1.0/24 via cni0` — local pod subnet.
- `192.168.0.0/24 via eth0` — node-to-node communication.

**Meaning:**
- Local pod-to-pod traffic goes through `cni0`.
- Cross-node pod traffic goes through `flannel.1` and the VXLAN tunnel.
- Node-to-node traffic goes through the physical/virtual NIC.

---

## 7. Demo: Services and Pods

### Service Details
- Service name: `hello-world`.
- Type: `NodePort`.
- ClusterIP: accessible inside the cluster.
- Port: `80`.
- NodePort: `30115`.
- TargetPort: `8080`.

### Accessing the Service
- From inside the cluster:
  ```bash
  curl http://<ClusterIP>:80
  ```
- From outside the cluster:
  ```bash
  curl http://<NodeIP>:30115
  ```
- Directly against a pod:
  ```bash
  curl http://<PodIP>:8080
  ```

### Behavior
- NodePort load balances across all pods behind the service.
- One of the four pods is selected to handle the request.
- The response includes “hello world”, version number, and host/pod name.

### Exec into a Pod
```bash
kubectl exec -it <pod-name> -- bash
```
- Runs an interactive shell inside the pod.
- From there, you can curl another pod on a different node.
- This traffic goes through the VXLAN tunnel.

---

## 8. Demo: Packet Capture with `tshark`

### What Is `tshark`?
- Command-line version of Wireshark.
- Used to monitor network traffic.

### Command Example
```bash
tshark -v -i eth0 -d udp.port==8472,vxlan -f "port 8472"
```
- `-v`: verbose output.
- `-i eth0`: capture on interface `eth0`.
- `-d udp.port==8472,vxlan`: interpret UDP port 8472 as VXLAN.
- `-f "port 8472"`: filter only port 8472.

### Flannel VXLAN Port
- Flannel uses UDP port **8472** for VXLAN.

### Packet Layers Observed
When a pod on one node calls a pod on another node:

1. **Outer Ethernet Frame**
   - Source MAC: local node interface.
   - Destination MAC: remote node interface.

2. **Outer IP Packet**
   - Source IP: local node IP.
   - Destination IP: remote node IP.

3. **UDP Header**
   - Source port: random.
   - Destination port: `8472`.

4. **VXLAN Header**
   - Identifies the VXLAN tunnel.

5. **Inner Ethernet Frame**
   - Source MAC: local pod/veth interface.
   - Destination MAC: remote pod/veth interface.

6. **Inner IP Packet**
   - Source IP: calling pod IP.
   - Destination IP: target pod IP.

7. **TCP Header**
   - Destination port: `8080` (the service port).

### Response Path
- The remote pod responds.
- The response is encapsulated again in VXLAN/UDP.
- It travels back through the tunnel to the original node.
- Then it is decapsulated and delivered to the calling pod.

### Key Point
- Many layers of encapsulation occur:
  - Ethernet → IP → UDP → VXLAN → Ethernet → IP → TCP.
- This is all transparent to the application.
- Flannel handles it automatically.

---

## 9. Summary of the Video
The presentation covered:
- High-level overview of the Kubernetes networking model.
- General overview of pod networking.
- CNI (Container Network Interface) — what it is and why it matters.
- Deep dive into the **Flannel CNI** plugin.
- Demo of Flannel in a real cluster.
- Verification of veth pairs, bridges, routes, and pod IPs.
- Service access via ClusterIP and NodePort.
- Packet capture with `tshark` to see VXLAN encapsulation in action.

---

## 10. Transcript Terms / Typos to Note
| Transcript Term | Correct Term |
|---|---|
| paws / part / compos | pods / pod |
| note | node |
| ipad | IP address |
| final one / flannel one | `flannel.1` |
| tan | tun |
| vxlan | VXLAN |
| t-sharp | tshark |
| cube ctl | `kubectl` |
| by cmp | ICMP |
| bet | veth |
| cni zero | `cni0` |
| udp panel | UDP packet / datagram |

---

## 11. Key Takeaways
- Kubernetes delegates pod networking to **CNI plugins**.
- **Flannel** is simple and uses **VXLAN** to connect pods across nodes.
- Same-node pod traffic uses a **bridge** (`cni0`).
- Cross-node pod traffic uses **`flannel.1`** and a **UDP tunnel** on port `8472`.
- Services provide stable access via **ClusterIP** and **NodePort**.
- `tshark` can reveal the full encapsulation stack: outer Ethernet/IP/UDP → VXLAN → inner Ethernet/IP/TCP.
- Everything works automatically once Flannel is installed and configured.