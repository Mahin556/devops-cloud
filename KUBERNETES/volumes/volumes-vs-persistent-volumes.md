* **Volumes**
  * Pod scoped.
  * Volume exist through out the lifecycle of pod.
  * Shared by all container of the pod to store logs, cache, temp files.

* **Persistence Volumes**
  * Cluster-Scoped Storage
  * They provide storage that is decoupled from Pods, meaning:
    * Data survives Pod restarts
    * Data persists even if the Pod is deleted
  * **Storage provisioning** (done by cluster admin or dynamic provisioning)
  * **Storage consumption** (done by developers using PVCs)