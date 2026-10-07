### References:-
- [Day 26: Kubernetes Volumes | Ephemeral Storage | emptyDir & downwardAPI DEMO](https://www.youtube.com/watch?v=Zyublb8bSbU&ab_channel=CloudWithVarJosh)
- https://www.devopsschool.com/blog/kubernetes-volume-emptydir-explained-with-examples/
- - [Kubernetes Volumes - emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [CKA Exam Curriculum](https://github.com/cncf/curriculum)

---

- Ephemeral storage refers to storage that is temporary, meaning that any data written to it only lasts for the duration of the Pod’s lifetime. When the Pod is deleted, the data is also lost.
- Enable containers within a Pod to share temporary storage(Scratch space within a Pod).

![Alt text](/images/26a.png)

**What is EmptyDir?**  
  - `emptyDir` is an empty directory created when a Pod is assigned to a node. The directory exists for the lifetime of the Pod.
  - If you define an `emptyDir` volume in a Deployment, each Pod created by the Deployment will have its **own unique** `emptyDir` volume. Since `emptyDir` exists **only as long as the Pod is running**, any data stored in it is **lost when the Pod is terminated or deleted**.  
  - It is shared by each and every container in the pod a long as each container mount that volume.
  - Defining an `emptyDir` in a Deployment ensures that **each Pod replica gets its own isolated temporary storage**, independent of other replicas. This is particularly useful for workloads where each Pod requires **scratch storage** that doesn’t need to persist beyond the Pod’s lifecycle.
  - It is fast because it is internal to the node. 
  - Using `emptyDir` enables inter-container file sharing within a Pod.
  - An emptyDir volume is first created when a Pod is assigned to a Node and initially its empty
  - If a container in a Pod crashes the emptyDir content is unaffected.
  - All containers in a Pod share use of the emptyDir volume .
  - Each container can independently mount the emptyDir at the same / or different path.
  - When a Pod is removed from a node for any reason, the data in the emptyDir is deleted forever along with the container.
  - A Container crashing does NOT remove a Pod from a node, so the data in an emptyDir volume is safe across Container crashes.
  - By default, emptyDir volumes are stored on whatever medium is backing the node – that might be disk or SSD or network storage.

**Why is it Used?**  
  It is ideal for scratch space (Temporary workspace for processing.), checkpointing a long computation for recovery from crashes , caching, or temporary computations where data persistence isn’t required.
  It is on the host so it is fast accessible then the external storage.

**Writable vs Read-Only Layers in Containers**
    If a Pod has **three containers** that all use the **same container image**, they **share the read-only image layer** to save space and optimize resource usage. However, **each container still gets its own writable layer**. So, any file changes or modifications done by one container remain **isolated** and are **not visible to the others**.
    But what if you want them to share data?
    That’s where **volumes** come into play—specifically, an `emptyDir` volume. If you mount the **same `emptyDir` volume** into all three containers, they now have access to a **shared writable space**. This allows them to **collaborate and share data** during the Pod’s lifetime, effectively **creating a shared writable layer** across containers.

**When Not to Use `emptyDir`**
* You need data to survive Pod restart, eviction, or rescheduling
    * `emptyDir` is deleted when the Pod is deleted or rescheduled.
    * If you need durable data → use a PVC (PersistentVolumeClaim).
    * Use instead:
      * PVC + storage class (EBS, NFS, Ceph, CSI drivers)

<br>
    
* Data is too large to fit on node’s local disk or RAM
  * emptyDir uses:
    * Node’s disk OR
    * Node’s memory (medium: "Memory")
  * If data may exceed node storage → use external storage.
  * Use instead:
    * S3 / GCS / Azure Blob
    * NFS
    * Ceph
    * Longhorn
    * CSI-backed volumes

<br>

* Workloads that must preserve data across deployments
  * StatefulSets, databases, message queues, ML models that need persistence
  * `emptyDir` is not appropriate
  * Use instead:
    * PVC (ReadWriteOnce / ReadWriteMany)

<br>

* Multi-pod shared storage
  * `emptyDir` cannot be shared between Pods
  * Only containers inside the same Pod can share it
  * Use instead:
    * PVC with RWX storage
    * NFS / CephFS / EFS

<br>

* Sensitive data requiring encryption at rest
  * `emptyDir` relies on node filesystem → no guaranteed encryption
  * Prefer PVCs backed by cloud-native encrypted storage

---

| Use Case                  | Storage Type | Persistence | Best Medium |
| ------------------------- | ------------ | ----------- | ----------- |
| Temporary scratch space   | Disk         | No          | `""`        |
| Shared between containers | Disk         | No          | `""`        |
| Log sharing               | Disk         | No          | `""`        |
| Caching                   | RAM          | No          | `"Memory"`  |
| Build workspace           | Disk         | No          | `""`        |
| Shared memory (IPC)       | RAM          | No          | `"Memory"`  |
| Staging uploads           | Disk         | No          | `""`        |

---

* **Where is emptyDir stored?**
  * Stored on node’s filesystem under:
    ```bash
    /var/lib/kubelet/pods/<pod-id>/volumes/kubernetes.io~empty-dir/<volname>/
    ```
    ```yaml
    emptyDir: {}
    ```
    * The {} at the end means we do not supply any further requirements for the emptyDir .
    ```yaml
    emptyDir:
      medium: ""
    ```
  * In RAM (tmpfs)
    * Uses node memory — extremely fast.
    ```yaml
    emptyDir:
      medium: "Memory"
      sizeLimit: "1Gi"
    ```

---
* **When to Use `emptyDir` (12 Real Use Cases)**
  * **Temporary scratch space**
    * ETL jobs
    * ML pipelines
    * Image/video processing

* **Shared storage between containers (sidecar pattern)**
    * Logger sidecar
    * Uploader sidecar
    * Proxy container

* **Buffering between app and sidecar**
    * Nginx writes logs → sidecar uploads to S3
    * App logs → Fluentd/Vector reads

* **Caching**
    * Package manager cache
    * ML intermediate cache
    * API response cache

* **Huge speed with RAM**
    * tmpfs
    * `/dev/shm`
    * computational scratch

* **Download/extraction workspace**
    * CI builds
    * Image processing
    * Data ingestion

* **CI/CD build workspace**
    * Tekton
    * Jenkins agents
    * Argo Workflows

* **Backup staging**
    * App writes → emptyDir
    * Sidecar uploads → PVC/S3

* **Decoupling temp data from PVC**
    * Don’t pollute persistent storage
    * Store only clean final output in PVC

* **CrashLoopBackOff recovery (container restarts but pod stays)**
    * Use emptyDir for:
      * lock files
      * partial progress

* **High-speed shared memory (`/dev/shm`)**
    * Chrome
    * PostgreSQL
    * TensorFlow/PyTorch

* **Serving temporary content**
    * Cache generated HTML files
    * Short-lived web artifacts

---


* **Types of `emptyDir`**
  ```yaml
  emptyDir:
    medium: ""        # default → stored on node disk
  ```
  or
  ```yaml
  emptyDir:
    medium: "Memory"  # stored in RAM (tmpfs)
  ```
  * `medium: ""` → Disk-based storage (default)
  * `medium: "Memory"` → RAM-based (faster, volatile)

---
* `tmpfs` is a temporary file system that stores data in volatile memory (RAM) instead of a disk, making it much faster. It appears as a normal file system but is temporary, with all data lost after a reboot or unmount. It is used for temporary files in places like /tmp, /run, and /dev/shm, which can improve performance and is also used for temporary storage in containers. 
* Common uses
  * `/tmp`: A common location for storing temporary files created by users and applications, as seen on Super User.
  * `/run`: Stores runtime data, such as process IDs, for programs that are running, which is only relevant while the system is active.
  * `/dev/shm`: Used for POSIX shared memory, a way for different processes to share data.
  * `Containers`: Provides ephemeral storage for containers, as shown in AWS Builder Center and Docker Docs. 

* since K8s `v1.22` you can set sizeLimit (feature SizeMemoryBackedVolumes) to get a predictable tmpfs size. Otherwise use container memory limits or a privileged tmpfs mount as a fallback.
* Default tmpfs size historically ≈ 50% of node RAM (may vary).
* Kubernetes v1.22+: sizeLimit for memory-backed emptyDir is supported (feature enabled by default).
    * `sizeLimit` on memory-backed emptyDir -> hard limit enforced by kernel (writes fail with ENOSPC).
    * `sizeLimit` on disk-backed emptyDir -> soft (eviction-based), not a strict quota.
