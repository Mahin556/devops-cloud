#### DaemonSet Best Practices
* **Restart Policy**
  * Set to `Always` or leave unspecified.
  * Ensures DaemonSet pods **automatically restart** if they fail.

* **Namespace Isolation**
  * Deploy each DaemonSet in its **own namespace**.
  * Helps in **resource management** and avoids conflicts with other DaemonSets.

* **Scheduling Preferences**
  * Prefer `preferredDuringSchedulingIgnoredDuringExecution` over `requiredDuringSchedulingIgnoredDuringExecution`.
  * Reason: If required nodes are unavailable, pods won’t start at all. Preferred scheduling is **flexible**.

* **DaemonSet Priority**
  * Set `priorityClassName` to **high priority** (≥ 10000).
  * Prevents critical DaemonSet pods from being **evicted** under resource pressure.

* **Pod Selector**
  * Must match `.spec.template.labels`.
  * Ensures **correct pods are managed** by the DaemonSet controller.

* **minReadySeconds**
  * Defines how long Kubernetes should wait before creating the next pod.
  * Guarantees that **existing pods are ready** before new pods are rolled out during updates.

* **Node Deployment**
  * Use proper **labels and node selectors** to deploy pods only on intended nodes.
  * Useful for **specialized workloads**, e.g., monitoring agents or network plugins.

* **Resource Requests/Limits**
  * Keep CPU and memory requests **minimal** because pods run on every node.
  * Prevents unnecessary resource consumption cluster-wide.

* **PodDisruptionBudgets (PDB)**
  * Define PDB to control **eviction during maintenance or upgrades**.
  * Ensures that **enough DaemonSet pods remain running** to maintain functionality.