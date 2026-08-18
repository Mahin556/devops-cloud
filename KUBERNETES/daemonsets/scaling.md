### **DaemonSet Scaling Concept**
  * **DaemonSets** automatically ensure **one Pod per node** (or per matching node).
  * You **cannot use** `kubectl scale` like you do with Deployments.
  * Scaling occurs **indirectly** by:
    * Adding nodes → **scales up** (creates new pods)
    * Removing nodes → **scales down** (deletes pods)
```bash
kubectl label node node01 type=demo
```
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: splunk-monitoring-agent
  labels:
    app: demo
spec:
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      nodeSelector:
        type: demo  # Ensures it runs on specific nodes with the label "platform-tools"
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

* **Manually Scaling a DaemonSet to Zero**
  * If you want to *temporarily remove all DaemonSet pods*, you can use a **non-matching node selector** to stop the DaemonSet from scheduling on any node.
  ```bash
  kubectl patch daemonset <daemonset-name> -n <namespace> \
    -p '{"spec": {"template": {"spec": {"nodeSelector": {"none": "match"}}}}}'
  ```
  ```bash
  kubectl patch daemonset splunk-monitoring-agent -n kube-system \
    -p '{"spec": {"template": {"spec": {"nodeSelector": {"dummy-nodeselector": "foobar"}}}}}'
  ```
  * This applies a fake label (`none=match`) that doesn’t exist on any node.
  * Result → All existing DaemonSet pods are **terminated**, and **no new pods** will be scheduled.

* **Scale Back to Normal**
  * To restore it, simply remove the dummy selector or reapply the original configuration:

* Option 1: Remove the selector completely
  ```bash
  kubectl patch daemonset splunk-monitoring-agent -n kube-system \
    -p '{"spec": {"template": {"spec": {"nodeSelector": null}}}}'
  ```

* Option 2: Restore the real selector
  ```bash
  kubectl patch daemonset splunk-monitoring-agent -n kube-system \
    -p '{"spec": {"template": {"spec": {"nodeSelector": {"type": "platform-tools"}}}}}'
  ```

* **Verification**
  * Check DaemonSet pods before and after:
  ```bash
  kubectl get pods -n kube-system -l app=logging -o wide
  ```
  * When scaled down → **No pods should appear**.
  * When restored → Pods will **reappear on all matching nodes**.
