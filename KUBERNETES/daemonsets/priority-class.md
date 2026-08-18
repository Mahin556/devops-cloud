#### Purpose of Pod Priority
  * Determines the **importance of a pod** relative to other pods.
  * Higher priority pods are **less likely to be preempted** when resources are scarce.
  * Useful for critical system components.
  * Critical system components (like `kube-proxy` or CNI pods) often use high-priority classes.
  * Ensures **critical DaemonSet pods remain running**, even under node resource pressure.
  * Useful for components like network plugins, logging agents, or monitoring daemons that must always be active.

* **PriorityClass Object**
  * Defines the priority value of a pod.
  * Can be any **32-bit integer ≤ 1 billion**.
  * Higher value → higher priority.

* **Example PriorityClass Creation**
  ```yaml
  apiVersion: scheduling.k8s.io/v1
  kind: PriorityClass
  metadata:
    name: high-priority
  value: 100000
  globalDefault: false
  description: "daemonset priority class"
  ```

  * Check existing priority classes:
    ```bash
    kubectl get priorityclass
    ```

* **Using PriorityClass in DaemonSet**
  ```yaml
  spec:
    priorityClassName: high-priority
    containers:
      ...
    terminationGracePeriodSeconds: 30
    volumes:
      ...
  ```

* **Built-in Critical Priority Classes**
  * `system-node-critical` → highest priority for node-level essential pods; not evicted under any circumstances.
  * `system-cluster-critical` → high priority for cluster-critical pods.