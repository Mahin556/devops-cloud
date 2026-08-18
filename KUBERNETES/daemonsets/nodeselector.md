
### Scoping DaemonSets to Specific Nodes
* DaemonSets don’t always need to run on every node.  
* You can restrict them to run only on selected nodes using:
  • `spec.template.spec.nodeSelector`  
  • `spec.template.spec.affinity`  
* Example: Fluentd DaemonSet restricted to nodes with log collection enabled:

```bash
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      nodeSelector:
        log-collection-enabled: "true"
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:latest

Before applying the DaemonSet, label the node:
  kubectl label node minikube-m02 log-collection-enabled=true
Now apply the manifest:
  kubectl apply -f fluentd.yaml
Check the DaemonSet:
  kubectl get daemonsets
You’ll see DESIRED = 1 because only one node matches the selector.
Confirm the Pod’s node placement:
  kubectl get pod -o wide
The Pod should be scheduled on the labeled node.
```

#### nodeSelector
* Normally, a DaemonSet schedules one Pod per node across the entire cluster. But sometimes, you don’t want it on *every node*, only on a subset of nodes (e.g., logging agents only on worker nodes). That’s where **nodeSelector** (or affinities/taints) comes in.
```bash
kubectl label node k8s-worker-1 type=platform-tools
kubectl label node k8s-worker-2 type=platform-tools
```
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: splunk-monitoring-agent
  labels:
    app: logging
spec:
  selector:
    matchLabels:
      app: logging
  template:
    metadata:
      labels:
        app: logging
    spec:
      nodeSelector:
        type: platform-tools  # Ensures it runs on specific nodes with the label "platform-tools"
      containers:
        - name: splunk-monitoring-agent
          image: splunk:latest
          ports:
            - containerPort: 8088  # Assuming the agent exposes a port
          volumeMounts:
            - name: splunk-config
              mountPath: /etc/splunk  # Specify where the config should be mounted in the container
      volumes:
        - name: splunk-config
          configMap:
            name: splunk-config-map  # Ensure you have a ConfigMap named splunk-config-map
```
* The controller looks at all nodes.
* Only nodes that match the selector get a Pod.
* Nodes without that label are skipped (DaemonSet won’t schedule Pods there).
* If you add a new node with that label, DaemonSet will automatically create a Pod on it.