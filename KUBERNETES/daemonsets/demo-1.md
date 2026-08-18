## **Demo: DaemonSet - Deploying a Dummy Logging Agent**

In this demo, we will deploy a **dummy logging agent** across all nodes in our Kubernetes cluster using a **DaemonSet**.  
The agent will simulate log collection by printing a message every 30 seconds.

As a best practice, **system-level DaemonSets are typically deployed into their own dedicated namespace** for better organization and access control.

---

### **Step 1: Create a New Namespace for Logging**

We will create a new namespace called `logging-ns` to isolate our DaemonSet:

```bash
kubectl create namespace logging-ns
```

---

### **Step 2: Switch the Context to the New Namespace**

To avoid typing `-n logging-ns` with every command, we will temporarily set the default namespace in our current context:

```bash
kubectl config set-context --current --namespace=logging-ns
```

This ensures that all our upcoming commands automatically target the `logging-ns` namespace.

---

### **Step 3: Apply the DaemonSet Manifest**

Here’s the manifest (`ds.yaml`) for our dummy logging agent:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  namespace: logging-ns  # Best practice: Deploy system-level agents into a dedicated namespace for better management and isolation.
  labels:
    app: log-collector  # Label to identify the DaemonSet and its Pods.
spec:
  selector:
    matchLabels:
      app: log-collector  # Ensures Pods managed by this DaemonSet match this label.
  template:
    metadata:
      labels:
        app: log-collector  # Labels assigned to Pods created by this DaemonSet.
    spec:
      tolerations:
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
          # This toleration allows Pods created by this DaemonSet to be scheduled even on control-plane nodes,
          # which are tainted by default with "NoSchedule" to block regular workloads.
      containers:
        - name: log-collector
          image: busybox  # Using a lightweight busybox image to simulate a logging agent.
          command: ["/bin/sh", "-c", "while true; do echo 'Collecting logs...'; sleep 30; done"]
          # The container runs an infinite loop that prints a message every 30 seconds, simulating log collection behavior.
          resources:
            requests:
              cpu: "50m"
              memory: "50Mi"
              # Resource requests ensure the scheduler reserves at least this much CPU and memory for the container.
            limits:
              cpu: "100m"
              memory: "100Mi"
              # Resource limits prevent the container from consuming more than the specified amount of CPU and memory.
          volumeMounts:
            - name: varlog
              mountPath: /var/log
              # Mounts the host's /var/log directory into the container, simulating real-world log collection from the node.
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
            type: Directory
            # A hostPath volume that provides direct access to the host machine’s /var/log directory.
            # In production, instead of just echoing logs inside the container, a real logging agent (like Fluentd, Fluent Bit, or Filebeat)
            # would collect logs from /var/log and ship them to a centralized destination such as:
            # - A file storage server (e.g., NFS, EFS)
            # - An object storage service (e.g., AWS S3, Google Cloud Storage)
            # - A logging service (e.g., ElasticSearch, Loki, Splunk)
            #
            # This ensures logs are persisted, searchable, and available for audits, troubleshooting, and monitoring.

```

Apply the DaemonSet using:

```bash
kubectl apply -f ds.yaml
```

> **Note:**  
> Here we are using a `hostPath` volume to simulate access to the node’s `/var/log` directory.  
> **In production environments**, logs would typically be shipped to a **centralized file storage** (like NFS), an **object storage** (like AWS S3), or **streamed directly** to a logging platform (like ElasticSearch, Loki, or a cloud-native log service).

---

### **Step 4: Verify the DaemonSet**

Check the DaemonSet status:

```bash
kubectl get daemonset
```

Describe the DaemonSet for more details:

```bash
kubectl describe daemonset log-collector
```

You should see that **one Pod is scheduled on every node** in the cluster.

Additionally, you can confirm the Pod placement with:

```bash
kubectl get pods -o wide
```

Example output:

```
NAME                  READY   STATUS    RESTARTS   AGE   IP            NODE                              NOMINATED NODE   READINESS GATES
log-collector-4krdf   1/1     Running   0          11m   10.244.1.26   my-second-cluster-worker          <none>           <none>
log-collector-bzsln   1/1     Running   0          11m   10.244.2.43   my-second-cluster-worker2         <none>           <none>
log-collector-nvvz4   1/1     Running   0          11m   10.244.0.5    my-second-cluster-control-plane   <none>           <none>
```

You can observe that **each node**, including the **control-plane node**, is running an instance of the log-collector Pod.  
This is possible because **we added a toleration** for the `control-plane` taint in the DaemonSet spec.

---

### **Bonus Exercise: Observe DaemonSet Pod Re-Creation**

To understand how the **DaemonSet controller** maintains the Pods:

1. **Manually delete a Pod** created by the DaemonSet:

```bash
kubectl delete pod <pod-name>
```

2. Immediately run:

```bash
kubectl get pods -o wide
```
 
We can also delete the namespace:
```bash
kubectl delete namespace <namespace>
```
You will see that **Kubernetes automatically recreates the missing Pod** on the same node.

> This demonstrates that the **DaemonSet controller constantly monitors the cluster** and ensures that **the desired state is maintained** — one Pod on every node.
