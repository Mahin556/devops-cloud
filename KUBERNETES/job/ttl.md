* It defines how long (in seconds) Kubernetes should **keep the Job and its Pods after completion** — whether the Job **Succeeded** or **Failed**.
* Once the time expires, the **TTL Controller** automatically deletes:
  * The **Job object**
  * The **Pods** created by that Job

* Prevent clutter from hundreds or thousands of completed jobs.
* Reduce load on the **Kubernetes API server**.
* Keep namespaces clean in environments with frequent Jobs (like CronJobs, pipelines, etc.).
* Set a **short TTL** (e.g. 300–1800 seconds) for **routine Jobs**.
* For debugging or critical tasks, omit TTL until you verify the results manually.
* Combine with **`CronJobs`** to prevent job accumulation over time.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-job
spec:
  ttlSecondsAfterFinished: 300   # 🕒 Deletes 5 minutes after completion
  backoffLimit: 2                # Retry failed Pods twice
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: cleanup
        image: busybox
        command: ["sh", "-c", "echo Cleaning up... && sleep 10"]
```


### **Behavior Summary**

| State         | What Happens                          | When Deleted              |
| ------------- | ------------------------------------- | ------------------------- |
| `Running`     | Job is still active                   | Not affected              |
| `Succeeded`   | Job finished successfully             | Deleted after TTL seconds |
| `Failed`      | Job failed (and backoffLimit reached) | Deleted after TTL seconds |
| `TTL omitted` | Job remains indefinitely              | Must be deleted manually  |


#### **Check if the TTLAfterFinished feature gate is enabled on your cluster’s kube-controller-manager.**
* Most modern clusters (v1.21+) have it **enabled by default**.

* **If You Have Access to Control Plane (kubeadm / self-managed cluster)**
    ```bash
    kubectl get pods -n kube-system | grep controller-manager

    kube-controller-manager-master-01
    kube-controller-manager-master-02
    ```
    ```bash
    kubectl -n kube-system describe pod kube-controller-manager-controlplane | grep feature-gates
    ```
    ```bash
    --feature-gates=TTLAfterFinished=true
    ```
    ```bash
    cat /etc/kubernetes/manifests/kube-controller-manager.yaml | grep feature-gates
    ```
    ```bash
    - --feature-gates=TTLAfterFinished=true
    ```
    * If not enabled, the TTL field will be ignored (Jobs won’t auto-delete).

* **If You’re on a Managed Cluster (EKS / GKE / AKS)**
    * You cannot directly modify controller-manager flags, but you can check Kubernetes version — since all modern versions have TTL enabled by default.
        ```bash
        kubectl version
        Server Version: v1.21 or higher
        ```
    * Then TTLAfterFinished is automatically enabled (no feature gate needed), All managed providers (EKS, GKE, AKS, DigitalOcean, etc.) enable it by default from v1.21+.



