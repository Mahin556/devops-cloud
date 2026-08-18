![Alt text](/images/29a.png)

• When new nodes join the Kubernetes cluster, the **DaemonSet controller** automatically creates a Pod on each new node.

• When a node is removed, Kubernetes automatically **garbage-collects (deletes)** the DaemonSet Pod that belonged to that node.

• If you manually delete a Pod created by a DaemonSet, the DaemonSet controller will **immediately recreate** it to maintain the desired state.

• If you delete the DaemonSet itself, Kubernetes will automatically **delete all Pods** that the DaemonSet had created.

• You can control whether a DaemonSet should run on control-plane nodes using **tolerations + nodeSelector**.  
  Example: kube-proxy runs on control-plane nodes because it includes the necessary tolerations.

---

### Static pod vs daemonsets
* Static pod node-scoped, daemonsets provide cluster level control.
* daemonsets --> scale in/out pod based on adding/removing of nodes.
* static pod --> each node kubelet manage a pod independently.
* to scale static pod we need to manally place a pod manifest into the kubelet monitored directory.

------------------------------------------------------------

### kube-proxy (DaemonSet)
• Kube-proxy manages **Service → Pod networking**.  
• It ensures traffic is routed only to **healthy Pods/nodes**.  
• Kube-proxy rewrites the **destination IP** for packets when a request hits a Service, sending it to the correct Pod.

------------------------------------------------------------

### How traffic flows:
Frontend Pod → accesses Service DNS name → CoreDNS resolves Service name → cluster IP → kube-proxy rewrites destination → forwards traffic to backend Pod

------------------------------------------------------------

### kube-proxy runs as a DaemonSet
• Ensures 1 kube-proxy Pod per node  
• Includes tolerations so it can also run on **control-plane nodes**  

---

### **DaemonSets We Have Already Seen: kube-proxy**

We have actually been working with a DaemonSet since early in this course.

- **Kube-proxy**, a critical system component responsible for **Service-to-Pod networking** inside the cluster.

- **kube-proxy** is deployed as a **DaemonSet** in Kubernetes to ensure that **every node** has the necessary networking functionality.
- You can verify this in your cluster using:

```bash
kubectl get daemonsets.apps -n kube-system kube-proxy
kubectl get pods -n kube-system -o wide | grep -i kube-proxy
```

---

### **DaemonSets for CNIs and CSIs**

Most cloud-native networking (CNI) and storage (CSI) plugins are deployed using DaemonSets:

- **CNI Plugins:**  
  AWS VPC CNI, Azure CNI, Calico, Flannel, Cilium
- **CSI Node Plugins:**  
  AWS EBS CSI, AWS EFS CSI, GCP PD CSI, and others

By deploying these plugins as DaemonSets, Kubernetes ensures that **every new or existing node** has the necessary networking and storage components running to handle Pod traffic, volume mounts, and attachments properly.

---

### **DaemonSets and Control Plane Nodes**

**Will a DaemonSet run on the control plane node?**  
The answer depends on the cluster setup:

- In **cloud-managed Kubernetes** services (like EKS, GKE, AKS), the **control plane nodes are fully managed** and **isolated**.  
  Therefore, **DaemonSets that you deploy for monitoring, logging, or security will not run on the control plane nodes**.

- In a **self-managed cluster** (like a cluster created with kubeadm or KIND), **DaemonSets can run on control plane nodes** if:
  - The control plane node has a **taint** (typically `node-role.kubernetes.io/control-plane:NoSchedule`), **and**
  - The DaemonSet has a **toleration** allowing it to tolerate that taint.

In our **KIND cluster**, we have three nodes:

```bash
kubectl get nodes
```

Output:

```
NAME                              STATUS   ROLES           AGE   VERSION
my-second-cluster-control-plane   Ready    control-plane   40d   v1.31.4
my-second-cluster-worker          Ready    <none>          40d   v1.31.4
my-second-cluster-worker2         Ready    <none>          40d   v1.31.4
```

The **control plane node** (`my-second-cluster-control-plane`) has the following taint:

```
Taints: node-role.kubernetes.io/control-plane:NoSchedule
```

You can verify it by running:

```bash
kubectl describe node my-second-cluster-control-plane
```

Now, the `kube-proxy` DaemonSet has the following toleration:

```yaml
tolerations:
  - operator: Exists
```

**What does it mean when `operator: Exists` is used without a `key`?**

- **No key specified** means the pod **tolerates *any* taint on the node** — regardless of key, value, or taint source.
- As long as the `effect` matches (or if no effect is specified, it tolerates any effect too), **the pod can be scheduled**.

In kube-proxy's case:
- kube-proxy must run on **all nodes** — control plane nodes, worker nodes, tainted nodes — everywhere.
- Kubernetes can't predict what taints the nodes may have (some clusters are custom).
- Instead of listing specific taint keys, kube-proxy's DaemonSet says:
  > "I don't care what taints the node has. I need to run there anyway."

---

### **Key Takeaways**

- A **DaemonSet** ensures that a specific Pod runs on **every node** in the cluster.
- It automatically handles Pod scheduling on new nodes and cleans up Pods from removed nodes.
- DaemonSets are heavily used for system-level components such as networking, storage, logging, monitoring, and security.
- On **managed cloud clusters**, DaemonSets generally **do not run on control plane nodes**.
- On **self-managed clusters**, DaemonSets **can run on control plane nodes** if appropriate **tolerations** are specified.


---

![](/images/image-4-44.png)
![image](https://github.com/piyushsachdeva/CKA-2024/assets/40286378/bb803dc2-f9ab-4fe3-a0bb-0eacdfcf3ce0)

---

* Node labels updated → Pods are added/removed based on label matching.
* Updating a DaemonSet
  - You can modify the Pod template in the DaemonSet.
  - Limitations:
      - Some fields in existing Pods cannot be updated.
      - The DaemonSet controller applies the original template when new nodes are added.

* Deleting a DaemonSet:
  - If a DaemonSet is deleted, the Pods it created are automatically cleaned up.
  - `--cascade=orphan` → Leaves Pods running on nodes.
  - Re-creating a DaemonSet with the same selector can adopt existing Pods.

```yaml
apiVersion: apps/v1
kind:  DaemonSet
metadata:
  name: nginx-ds
  labels:
    env: demo
spec:
  template:
    metadata:
      labels:
        env: demo
      name: nginx
    spec:
      containers:
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
  selector:
    matchLabels:
      env: demo
```

#### Example DaemonSet Manifest

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-agent
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: log-agent
  template:
    metadata:
      labels:
        name: log-agent
    spec:
      containers:
      - name: fluentd
        image: fluentd:latest
        resources:
          limits:
            memory: "200Mi"
            cpu: "200m"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```
* In this example, `fluentd` is deployed on every node to collect logs from `/var/log`.

### DaemonSet vs Deployment

* **Deployment**: Scales Pods arbitrarily across nodes, focuses on stateless apps.
* **DaemonSet**: Ensures **one Pod per node**, ideal for infrastructure-level services.
* **Deployment + HPA**: Used for scalable workloads (e.g., web apps).
* **DaemonSet**: Used for node-level background tasks.

#### Multiple DaemonSets for One Daemon

  * Sometimes, you need the *same kind daemon* (e.g., Fluentd or a monitoring agent) but with **different configurations** depending on hardware, node pool, or workload type.
  * Instead of trying to overload a single DaemonSet with complex logic, you can define **separate DaemonSets**, each scoped to the right nodes.

* **Use Cases**
  1. **Different Resource Requirements**
     * Example: Nodes with GPUs may need higher memory/CPU allocations for monitoring agents.
     * Solution: One DaemonSet with `resources.requests` tailored for GPU nodes, another with lighter requests for standard nodes.

  2. **Different Configuration Flags**
     * Example: A logging agent needs to parse logs differently on database nodes vs application nodes.
     * Solution: Deploy two DaemonSets, each mounting different config files via ConfigMap.

  3. **Different Hardware Types**
     * Example: Bare-metal nodes vs virtual machines may need different system daemons or driver-related flags.
     * Solution: Use multiple DaemonSets with `nodeSelector` / `nodeAffinity` targeting the correct hardware labels.

  4. **Mixed Operating Systems / Architectures**
     * Example: A cluster with both Linux and Windows nodes.
     * Solution: One DaemonSet runs the daemon container built for Linux (`nodeSelector: kubernetes.io/os=linux`), another for Windows.

* **Implementation**
  * Use **labels and selectors** to scope each DaemonSet:
    ```yaml
    spec:
      template:
        spec:
          nodeSelector:
            hardwareType: gpu
    ```
  * Alternatively, use **affinity rules** or **tolerations** for tainted node pools.












