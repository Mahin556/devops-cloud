#### Some Troubleshooting
* **When is a DaemonSet Unhealthy?**
  * Any pod in the DaemonSet is **not running on a node**.
  * Common pod statuses causing issues:
    * `CrashLoopBackOff` → pod repeatedly crashing.
    * `Pending` → pod cannot be scheduled.
    * `Error` → pod failed to start or encountered runtime issues.

* **Initial Troubleshooting Step**
  * Check pod logs to identify the issue:
    ```bash
    kubectl -n <NAMESPACE> logs <POD NAME> -f
    ```

* **Common Fixes**
  * **Resource issues:**
    * Pod might be running out of CPU or memory.
    * Reduce **resource requests/limits** in the DaemonSet spec.
  * **Node pressure:**
    * Move some pods off affected nodes.
    * Use **taints and tolerations** to control pod placement.
  * **Cluster capacity:**
    * Scale up the cluster by adding more nodes.
  * **Other pod troubleshooting:**
    * Check events: `kubectl describe pod <POD NAME> -n <NAMESPACE>`
    * Ensure container images exist and are accessible.
    * Validate network connectivity if required by the pod.

* **Key Tip**
  * Since DaemonSets run **on all (or selected) nodes**, even a single node issue can make the DaemonSet appear unhealthy. Start troubleshooting **node by node**.
