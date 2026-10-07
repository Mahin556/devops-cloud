### References:
- [Day 27: Kubernetes Volumes | Persistent Storage | PV, PVC, StorageClass, hostPath DEMO](https://www.youtube.com/watch?v=C6fqoSnbrck&ab_channel=CloudWithVarJosh)
- https://devopscube.com/kubernetes-deployment-tutorial/
- [Kubernetes Volumes Documentation](https://kubernetes.io/docs/concepts/storage/volumes/)  
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)  
- [Kubernetes Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)  
- [CSI Documentation](https://kubernetes-csi.github.io/docs/)
- https://spacelift.io/blog/kubernetes-persistent-volumes
---

![Alt text](/images/27c.png)

* Applications often require storage to persist data, ensuring it remains intact even if pods are restarted or terminated. 
* Kubernetes provides **Persistent Volumes (PV)** and **Persistent Volume Claims (PVC)** to manage this storage.
* Most of the application(mostly stateful application such as databases or file servers) that run in kubernetes required persistent storage which is enable by PV, PVC, SC.

### Steps to Mount a Persistent Volume

1. **Create a Persistent Volume (PV)** – defines the actual storage.
2. **Create a Persistent Volume Claim (PVC)** – requests the storage defined in the PV.
3. **Mount the volume** in your application container at the desired directory.

---

### **Persistent Volumes (PVs)**
  - K8S object.
  - A PV is a piece of storage in your cluster that has been provisioned either manually by an administrator or dynamically using Storage Classes.
  - Logical Abstraction over a physical storage:
    - NFS
    - AWS EBS
    - Azure Disk
    - GCE Persistent Disk
    - Ceph
    - Local disk
  - PVs exist independently of Pod lifecycles and can be reused or retained even after the Pod is deleted. They have properties such as **capacity, access modes, and reclaim policies**.

### **Persistent Volume Claims (PVCs)**
  - K8S object.
  - A PVC is a request for storage by a user. It functions similarly to how a Pod requests compute resources. When a PVC is created, Kubernetes searches for a PV that meets the claim's requirements or SC creates a PV with the requitements specify in the PVC specification.
  - **Binding Process:**  
    1. **Administrator:** Provisions PVs (or sets up Storage Classes for dynamic provisioning).  
    2. **Developer:** Creates a PVC in the Pod specification requesting specific storage attributes.  
    3. **Kubernetes:** Binds the PVC to a suitable PV, thereby making the storage available to the Pod.

Dev(Container, pod) ---> K8S Admin(PV,PVC) ---> Storage Admin(Physical storage)
PV ---> automate ---> Storage Classes

**Pods rely on Node resources—such as CPU, memory, and network—to run containers.** On the other hand, when a Pod requires **persistent storage**, it uses a **PersistentVolumeClaim (PVC)** to request storage from a **PersistentVolume (PV)**, which serves as the **actual storage backend**. This separation of compute and storage allows Kubernetes to manage them independently, improving flexibility and scalability.

---

### **Understanding Scope & Relationships of PV and PVC in Kubernetes**

![Alt text](/images/27e.png)

##### **PVs are Cluster-Scoped Resources**
- A **PersistentVolume (PV)** is a **cluster-wide resource**, just like Nodes or StorageClasses.
- This means it is **not tied to any specific namespace**, and it can be viewed or managed from anywhere within the cluster.
- You can verify this using:
  ```bash
  kubectl api-resources | grep persistentvolume
  ```
  This shows that the resource `persistentvolumes` has **no namespace**, indicating it's **cluster-scoped**.


##### **PVCs are Namespace-Scoped**
- A **PersistentVolumeClaim (PVC)**, on the other hand, is a **namespaced resource**, just like Pods or Deployments.
- This means it exists **within a specific namespace** and is only accessible by workloads (Pods) within that namespace.
- You can verify this using:
  ```bash
  kubectl api-resources | grep persistentvolumeclaim
  ```
  This shows that `persistentvolumeclaims` are scoped within a namespace.
  
---

##### **Why Is This Important?**
- Let’s say you have a namespace called `app1-ns`. If a PVC is created in `app1-ns` and binds to a PV, **only Pods in `app1-ns` can use that PVC**.
- If a Pod in `app2-ns` tries to reference the same PVC, it will fail — because the PVC is invisible and inaccessible outside its namespace.

---

##### **1-to-1 Binding Relationship Between PVC and PV**
- A **PVC can bind to only one PV**.
- Similarly, **a PV can be bound to only one PVC**.
- This is a **strict one-to-one relationship**, ensuring data integrity and predictable access control.
- Once a PV is bound, its `claimRef` field is populated, and it cannot be claimed by any other PVC unless explicitly released.
  ```yaml
  spec:
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: my-pvc
    namespace: default
  ```

> **`claimRef`** is a field in a **PersistentVolume (PV)** that records which **PersistentVolumeClaim (PVC)** has successfully claimed it. It includes details like the PVC’s name and namespace. This field ensures that the PV is not mistakenly claimed by any other PVC, enforcing a **one-to-one binding** between the PV and its assigned PVC.
- PVCs consume PVs

---

- **PVCs request storage**; PVs **fulfill that request** if they match capacity, access mode, and storage class.
- Once a PVC is bound, **it remains bound** until:
  - The PVC is deleted.
  - The PV is manually reclaimed or deleted (depending on the reclaim policy).
- The reclaim policy (`Retain`, `Delete`, or deprecated `Recycle`) determines what happens to the PV after the PVC is deleted.

---

### **Kubernetes Persistent Storage Flow (Manual Provisioning)**

![Alt text](/images/27c.png)

| **Step** | **Role**                | **Action**                                                                                          | **Details / Notes**                                                                 |
|----------|-------------------------|------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| 1        | **Developer**           | Requests 5Gi persistent storage for a Pod.                                                           | May request via a PVC or through communication with the Kubernetes Admin.          |
| 2        | **Kubernetes Admin**    | Coordinates with Storage Admin for backend volume.                                                  | Backend storage could be SAN/NAS exposed via iSCSI, NFS, etc.                      |
| 3        | **Storage Admin**       | Allocates a physical volume from a 500Ti storage pool.                                               | May involve LUN creation, NFS export, etc., based on the infrastructure.            |
| 4        | **Kubernetes Admin**    | Creates a **PersistentVolume (PV)** representing the physical volume in Kubernetes.                 | Specifies capacity, `accessModes`, `volumeMode`, `storageClassName`, etc.          |
| 5        | **Developer**           | Creates a **PersistentVolumeClaim (PVC)** requesting 5Gi with specific access and volume modes.     | PVC must match criteria defined in the PV.                                          |
| 6        | **Kubernetes**          | Binds PVC to a suitable PV if all parameters match.                                                 | Matching criteria include: storage class, access mode, volume mode, size, etc.     |
| 7        | **Pod**                 | References the PVC in its volume definition and mounts it in a container.                          | PVC acts as an abstraction; Pod doesn’t interact with the PV directly.             |

---


- Communication with physical storage is handled by either:
  - **In-tree drivers** (legacy; e.g., `awsElasticBlockStore`, `azureDisk`)
  - **CSI drivers** (modern; e.g., `ebs.csi.aws.com`, `azurefile.csi.azure.com`)

> In many cases, developers are well-versed with Kubernetes and can handle the creation of **PersistentVolumeClaims (PVCs)** themselves. With the introduction of **StorageClasses**, the process of provisioning **PersistentVolumes(PVs)** has been **automated**—eliminating the need for Kubernetes administrators to manually coordinate with storage admins and pre-create PVs. When a PVC is created with a **StorageClass**, Kubernetes **dynamically provisions** the corresponding PV. We’ll explore StorageClasses in detail shortly.

---

#### **Access Modes in Kubernetes Persistent Volumes**

Persistent storage in Kubernetes supports various access modes that dictate how a volume can be mounted by Pods and Nodes. Access modes essentially govern how the volume is mounted across **nodes**, which is critical in clustered environments like Kubernetes.

These access modes determine:
  * Whether a volume is read-only or read-write
  * Whether it can be mounted by one Pod or many
  * Whether multiple Nodes can access it simultaneously

once ---> block storage
many ---> file storage

- It should be same on both PV and PVC for bounding.


| **Access Mode**          | **Description**                                                                                          | **Example Use Case**                                            | **Type of Storage & Examples** |
|--------------------------|----------------------------------------------------------------------------------------------------------|----------------------------------------------------------------|--------------------------------|
| **ReadWriteOnce (RWO)**  | The volume can be mounted as read-write by a **single node**. Multiple Pods can access it **only if** they are on the same node. | Databases that require exclusive access but may run multiple replicas per node. Databases, single-node apps, workloads tied to a specific Node.  | **Block Storage** (e.g., Amazon EBS, GCP Persistent Disk, Azure Managed Disks) |
| **ReadOnlyMany (ROX)**   | The volume can be mounted as **read-only** by **multiple nodes** simultaneously.                        | Sharing static data like configuration files or read-only datasets across multiple nodes, package repositories. | **File Storage** (e.g., NFS, Azure File Storage) |
| **ReadWriteMany (RWX)**  | Volume can be mounted on multiple Nodes, all with read-write access, Allows true shared storage across Pods and Nodes.                     | Content management systems, shared data applications, or log aggregation, Multi-replica apps needing shared state,NFS, CephFS, EFS, Azure Files, etc. | **File Storage** (e.g., Amazon EFS, Azure File Storage, On-Prem NFS) |
| **ReadWriteOncePod (RWOP)** (Introduced in v1.29) | The volume can be mounted as read-write by **only one Pod across the entire cluster**.                 | Ensuring exclusive access to a volume for a single Pod, such as in tightly controlled workloads. | **Block Storage** (e.g., Amazon EBS with `ReadWriteOncePod` enforcement) |

---

While there are exceptions, block storage is typically designed for single-system access, offering low-latency performance ideal for databases and high-throughput applications. On the other hand, file storage is generally intended for shared access across multiple systems, making it suitable for collaborative environments and workloads that require concurrent access. However, it's important to note that in some cases, block storage may be shared, and file storage may be used by a single system based on specific architecture or application needs.

| Storage Type            | Supported Modes | Notes                             |
| ----------------------- | --------------- | --------------------------------- |
| **hostPath**            | RWO             | Node-local only; dev/test use     |
| **local volumes**       | RWO             | High-performance node-local       |
| **NFS**                 | RWO, ROX, RWX   | True shared storage               |
| **CephFS**              | RWO, ROX, RWX   | Distributed filesystem            |
| **iSCSI / FC**          | RWO             | Block storage                     |
| **CSI Drivers (Cloud)** | Varies          | Depends on driver (AWS/GCP/Azure) |

---

### **Explanation of Storage Types**

#### **Block Storage**  
Block storage is ideal for databases and applications requiring **low-latency, high-performance storage**. It provides raw storage blocks that applications can format and manage as individual disks.  
- **Examples**: Amazon EBS, GCP Persistent Disk, Dell EMC Block Storage.  
- **Key Characteristic**: Block storage is generally **node-specific** and does not support simultaneous multi-node access.  
- **Access Modes**: Commonly used with `ReadWriteOnce` or `ReadWriteOncePod`, as these modes restrict access to a single node or Pod at a time.

*Analogy*: Block storage is like attaching a USB drive to a single computer—it provides fast, reliable storage but cannot be shared concurrently across multiple systems.
* Block device ---> format(ext4,vfat etc) ---> File Storage

#### **File Storage**  
File storage is designed for **shared storage scenarios**, where multiple Pods or applications need simultaneous access to the same data. It is mounted as a shared filesystem, making it ideal for distributed workloads.  
- **Examples**: Amazon EFS, Azure File Storage, On-Prem NFS (Network File System).  
- **Key Characteristic**: File storage is purpose-built for **multi-node concurrent access**.  
- **Access Modes**: File storage often supports modes like `ReadOnlyMany` or `ReadWriteMany`, allowing multiple Pods—across different nodes—to read from and write to the same volume.

*Analogy*: File storage works like a network drive, where multiple systems can access, update, and share files simultaneously.

---

### **Key Differences: Block Storage vs. File Storage**
1. **Multi-Node Access**: Block storage is single-node focused, whereas file storage allows concurrent access across multiple nodes.  
2. **Access Modes**: `ReadWriteOnce` or `ReadWriteOncePod` are typical for block storage, while `ReadWriteMany` is common for file storage due to its multi-node capabilities.  
3. **Use Cases**:  
   - **Block Storage**: Databases, transactional systems, or workloads requiring exclusive and high-performance storage.  
   - **File Storage**: Shared workloads like web servers, content management systems, and applications requiring shared configurations or assets.

---

When evaluating storage options, it's important to align the access modes and storage type with the needs of the workload. For example, "Many" in an access mode (`ReadOnlyMany` or `ReadWriteMany`) usually signals that the underlying storage is file-based and optimized for shared use.

---

### ✅ **Explanation of "Volume Mode: Block" and the Example**

The speaker is explaining **why some applications (like Oracle databases)** want the storage in **block mode** instead of file mode.

#### **Volume Mode = Block**

* When a Kubernetes PersistentVolume is set to **volumeMode: Block**, it is presented as a **raw block device** to the container — just like attaching a real hard drive.
* The **application itself** (like Oracle DB) decides how to format it.
* Kubernetes does **not** put a filesystem (ext4, xfs) on it.


### 🧩 **Why Databases Prefer Block Mode**

Databases (Oracle, SQL Server, etc.) often prefer:

* full control over how data is placed on disk
* better performance
* ability to tune the filesystem or storage format themselves

This is the same as giving them a **raw disk**.


### 🖥️ **VMware Example (RDM)**

He compares this to **VMware Raw Device Mapping (RDM)**:

* **VMFS = VMware's filesystem**
* But sometimes you don’t want VMFS; you want raw storage.
* So VMware lets you map the **raw LUN** directly to the VM.
* Then the **guest OS formats it**, not VMware.

This is exactly the same idea as Kubernetes block-mode volumes.


### 📌 **Summary**

| Setting                    | What it Means                         | Example Use Case                   |
| -------------------------- | ------------------------------------- | ---------------------------------- |
| **volumeMode: Block**      | Attach as raw disk, no filesystem     | Databases (Oracle), low-level apps |
| **volumeMode: Filesystem** | K8s automatically formats & mounts it | Regular apps, logs, web servers    |

### 📦 **Kubernetes YAML Example**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: raw-disk-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Block
  resources:
    requests:
      storage: 100Gi
```

This PVC will deliver a **raw disk** to the application.

---

### **Reclaim Policies in Kubernetes**  

Reclaim policies define what happens to a **PersistentVolume (PV)** when its bound **PersistentVolumeClaim (PVC)** is deleted. The available policies are:  


#### **1. Delete (Common for Dynamically Provisioned Storage)**  
- When the PVC is deleted, the corresponding PV and its underlying **storage resource** (e.g., cloud disk, block storage) are **automatically deleted**.  
- This is useful in **cloud environments** where storage resources should be freed when no longer in use. 
- Block storage 

**🔹 Example Use Case:**  
- **AWS EBS, GCP Persistent Disk, Azure Disk** – Storage dynamically provisioned via CSI drivers gets deleted along with the PV, preventing orphaned resources.  


#### **2. Retain (Manual Intervention Needed for Reuse)**  
- When the PVC is deleted, the PV remains in the cluster but moves to a **"Released"** state.  
- **The data is preserved**, and manual intervention is required to either:  
  - Delete and clean up the volume.  
  - Rebind it to another PVC by manually removing the claim reference (`claimRef`).  
- File storage

**🔹 Example Use Case:**  
- **Auditing & Compliance:** Ensures data is retained for logs, backups, or forensic analysis.  
- **Manual Data Recovery:** Useful in scenarios where storage should not be automatically deleted after PVC removal.  

#### **3. Recycle (Deprecated in Kubernetes v1.20+)**  
- This policy would automatically **wipe the data** (using a basic `rm -rf` command) and make the PV available for new claims.  
- It was removed in favor of **dynamic provisioning** and more secure, customizable cleanup methods.  

**🔹 Why Deprecated?**  
- Lacked customization for **secure erasure** methods.  
- Didn't support advanced cleanup operations (e.g., snapshot-based restoration).  

---

### **Choosing the Right Reclaim Policy**  

| **Reclaim Policy** | **Behavior** | **Best Use Case** | **Common in** |
|-------------------|------------|-----------------|----------------|
| **Delete** | Deletes PV and storage resource when PVC is deleted. | Cloud-based dynamically provisioned storage. | AWS EBS, GCP PD, Azure Disk. |
| **Retain** | Keeps PV and storage, requiring manual cleanup. | Backup, auditing, manual data recovery. | On-prem storage, long-term retention workloads. |
| **Recycle (Deprecated)** | Cleans volume and makes PV available again. | (Not recommended) | Previously used in legacy systems. |

![](/images/image1131312.png)
![](/images/image1.png)

---

### **PVC and PV Binding Conditions**  

For a **PersistentVolumeClaim (PVC)** to bind with a **PersistentVolume (PV)** in Kubernetes, the following conditions must be met:  

- **Matching Storage Class**  
  - The `storageClassName` of the PVC and PV must match.  
  - If the PVC does not specify a storage class, it can bind to a PV **without a storage class**.  

- **Access Mode Compatibility**  
  - The access mode requested by the PVC (`ReadWriteOnce`, `ReadOnlyMany`, `ReadWriteMany`) **must be supported** by the PV.  

- **Sufficient Storage Capacity**  
  - The PV’s storage **must be equal to or greater than** the requested capacity in the PVC.  

- **Volume Binding Mode**  
  - If set to `Immediate`, the PV binds as soon as a matching PVC is found.  
  - If set to `WaitForFirstConsumer`, binding happens **only when a pod** using the PVC is scheduled.  
    - Essential for:
      * Local PV
      * OpenEBS LocalPV
      * Node-specific storage

- **PV Must Be Available**  
  - The PV must be in the `Available` state (i.e., not already bound to another PVC).  
  - If the PV is already bound, it **cannot** be reused unless manually released.  

- **Matching Volume Mode**

    **Volume Modes** define how a Persistent Volume (PV) is presented to a Pod:
    1. **Block**: 
      * Provides raw block device, unformatted storage for the Pod. 
      * Application must format/mount it manually.
    2. **Filesystem(default)**:  
      * Presents a formatted PV is formatted with a filesystem (ext4/xfs)
      * Ready to use by applications for file-level operations.

    **Matching Modes**:  
    - A PVC requesting `volumeMode: Block` must match a PV with `volumeMode: Block`.  
    - A PVC requesting `volumeMode: Filesystem` must match a PV with `volumeMode: Filesystem`.

    **Use Case for `volumeMode: Block`**: 
      * This is typically used when an application, such as a database (e.g., PostgreSQL, MySQL), needs direct control over disk formatting, partitioning, or low-level I/O optimizations.
      * Databases, NoSQL, and applications needing raw I/O control.
      * Example: PostgreSQL on raw devices for performance tuning

    This ensures compatibility between Pods and their storage. 

- **Claim Reference (Manual Binding Cases)**  
  - If the PV has a `claimRef` field, it can **only bind** to the specific PVC mentioned in that field.  
    ```yaml
    spec:
      claimRef:
        name: my-pvc
        namespace: default
    ```

These conditions ensure a **seamless** and **reliable** binding process, providing persistent storage to Kubernetes workloads.  

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: manual-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem        # Must match PVC
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-sc   # Must match PVC
  nodeAffinity:                 # PV tied to a specific node
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
            - worker1           # <-- replace with your node name
  hostPath:
    path: /data/manual-demo
    type: DirectoryOrCreate
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: manual-pvc
spec:
  storageClassName: manual-sc       # Must match PV
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem            # Must match PV
  resources:
    requests:
      storage: 5Gi                  # Must be ≤ PV capacity
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: manual-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - mountPath: /appdata
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: manual-pvc         # Bind to PVC
```
---

### **Critical Note for KIND/Minikube Users**

If you're following along with this course, chances are you’ve installed **KIND (Kubernetes IN Docker)**. KIND comes with a **pre-configured default StorageClass** out of the box.  

If you're using **Minikube** instead, it's a good idea to check whether your cluster also includes a default StorageClass. You can verify this using the following command:

```bash
kubectl get storageclasses
```

Example output:
```bash
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  27d
```

---


#### **Why Modify the Default Storage Class?**

The default storage class (`standard`) interferes with our demo of Persistent Volumes (PVs) and Persistent Volume Claims (PVCs). For this reason, we will temporarily **delete it**. However, before deleting it, we’ll take a backup of the YAML configuration. This will allow us to recreate the storage class later when moving to the **Storage Classes** section.

1. **Backup the Default Storage Class Configuration**:
   Use the following command to back up the configuration into a file named `sc.yaml` in your current working directory:
   ```bash
   kubectl get sc standard -o yaml > sc.yaml
   ```
   - This ensures we can recreate the `standard` storage class later as needed.

2. **Delete the Storage Class**:
   Now, delete the `standard` storage class to prevent interference with the PV/PVC demo:
   ```bash
   kubectl delete sc standard
   ```
   Example output:
   ```
   storageclass.storage.k8s.io "standard" deleted
   ```

By following these steps, we ensure that the default configuration doesn’t disrupt our hands-on exercises and we can restore it later when necessary.


---

### **Summary Table: PVC and PV Binding Conditions**  

| **Condition**              | **Requirement for Binding**                                             |
|----------------------------|-------------------------------------------------------------------------|
| **Storage Class Match**     | `storageClassName` of PVC and PV must match (or both can be empty).   |
| **Access Mode Compatibility** | PVC’s requested access mode must be supported by PV.                 |
| **Sufficient Capacity**     | PV’s storage must be **≥** PVC’s requested capacity.                 |
| **Volume Binding Mode**     | Either `Immediate` or `WaitForFirstConsumer`.                         |
| **Volume State**           | PV must be in `Available` state to bind.                             |
| **Matching Volume Mode**    | PVC and PV must have the same `volumeMode` (`Filesystem` or `Block`). |
| **Claim Reference**         | If PV has a `claimRef`, it can only bind to that specific PVC.        |

---

### **Example Table: PVC vs. PV Matching**  

| **Condition**       | **PVC Requirement** | **PV Must Have**        |
|--------------------|---------------------|-------------------------|
| **Storage Capacity** | `size: 10Gi`        | `size ≥ 10Gi`           |
| **Access Mode**      | `ReadWriteMany`     | `ReadWriteMany`         |
| **Storage Class**    | `fast-ssd`          | `fast-ssd`              |
| **Volume State**     | `Unbound`           | `Available`             |
| **Volume Mode**      | `Filesystem`        | `Filesystem`            |

---

### **Demo: Persistent Volumes and PVCs with Reclaim Policy**

#### **Step 1: Create a Persistent Volume (PV)**

Create a file (for example, `pv.yaml`) with the following content:

```yaml
apiVersion: v1                       # Kubernetes API version
kind: PersistentVolume              # Defines a PersistentVolume resource
metadata:
  name: example-pv                  # Unique name for the PV
spec:
  capacity:
    storage: 5Gi                    # Total storage provided (5 GiB)
  accessModes:
    - ReadWriteOnce                # Volume can be mounted as read-write by a single node at a time
  persistentVolumeReclaimPolicy: Retain  # Retain the volume and data even when the PVC is deleted
  hostPath:
    path: /mnt/data                # Uses a directory on the node (for demo purposes only)
```

> **Note:** When the `ReclaimPolicy` is set to `Retain`, the PersistentVolume (PV) and its data will **not be deleted** even if the associated PersistentVolumeClaim (PVC) is removed. This means the storage is **preserved for manual recovery or reassignment**, and must be manually handled by an administrator before it can be reused.


**Apply the PV:**

```bash
kubectl apply -f pv.yaml
```

**Verify the PV:**

```bash
kubectl get pv
kubectl describe pv example-pv
```

<br>

#### **Step 2: Create a Persistent Volume Claim (PVC)**

Create a file (for example, `pvc.yaml`) with the following content:

```yaml
apiVersion: v1                       # Kubernetes API version
kind: PersistentVolumeClaim         # Defines a PVC resource
metadata:
  name: example-pvc                 # Unique name for the PVC
spec:
  accessModes:
    - ReadWriteOnce                # Request volume to be mounted as read-write by a single node
  resources:
    requests:
      storage: 2Gi                 # Ask for at least 2Gi of storage (must be ≤ PV capacity)
```

> **Key Point:**  
> Since this PVC doesn’t explicitly specify a StorageClass, it will bind to a compatible PV if available. In this demo, the PV created above offers 5Gi, making it a suitable candidate for a 2Gi claim.
But you can see PVC capacity 5Gi instead 2Gi.

**Apply the PVC:**

```bash
kubectl apply -f pvc.yaml
```

**Verify the PVC status:**

```bash
kubectl get pvc
kubectl describe pvc example-pvc
```

<br>

#### **Step 3: Create a Pod That Uses the PVC**

Create a file (for example, `pod.yaml`) with the following content:

```yaml
apiVersion: v1                       # Kubernetes API version
kind: Pod                           # Defines a Pod resource
metadata:
  name: example-pod                 # Unique name for the Pod
spec:
  containers:
    - name: nginx-container         # Name of the container
      image: nginx                  # Container image to use
      volumeMounts:
        - mountPath: /usr/share/nginx/html  # Directory inside the container where the volume will be mounted
          name: persistent-storage  # Logical name for the volume mount
  volumes:
    - name: persistent-storage      # Volume's name referenced above
      persistentVolumeClaim:
        claimName: example-pvc      # Bind this volume to the previously created PVC
```

> **Important:**  
> When this Pod is created, Kubernetes will bind the PVC to the appropriate PV (if not already bound) and mount the volume. At this point, the PVC status should change from "Pending" to "Bound".

**Apply the Pod:**

```bash
kubectl apply -f pod.yaml
```

**Verify the Pod and its Volume Attachment:**

```bash
kubectl describe pod example-pod
```

<br>

#### **Final Verification**

After creating these resources, use the following commands to check that everything is in order:

- **Persistent Volumes:**
  ```bash
  kubectl get pv
  kubectl describe pv example-pv
  ```
- **Persistent Volume Claims:**
  ```bash
  kubectl get pvc
  kubectl describe pvc example-pvc
  ```
- **Pod Details:**
  ```bash
  kubectl describe pod example-pod
  ```

By following these steps, you’ll see that the PVC is bound to the PV and the Pod successfully mounts the storage. 

You cannot delete a PersistentVolume (PV) that is currently bound to a PersistentVolumeClaim (PVC), and you cannot delete a PVC that is actively in use by a Pod. -container
Kubernetes prevents such deletions to ensure data integrity and avoid breaking workloads that rely on persistent storage.
Deletion order Pod-->PVC--->PV

---


### **Storage Classes & Dynamic Provisioning**

#### **What is a Storage Class?**

A **Storage Class** in Kubernetes is a way to define different storage configurations, enabling dynamic provisioning of Persistent Volumes (PVs). It eliminates the need to manually pre-create PVs and provides flexibility for managing storage across diverse workloads. 

- **Purpose**: Storage Classes define storage backends and their parameters, such as disk types, reclaim policies, and binding modes.  
- **Dynamic Provisioning**: When a Persistent Volume Claim (PVC) is created, Kubernetes uses the referenced Storage Class to automatically provision a corresponding PV.  
- **Flexibility**: 
  - Multiple Storage Classes can coexist in a Kubernetes cluster, allowing administrators to tailor storage types for varying application needs (e.g., high-performance SSDs, low-cost storage, etc.).
  - Diff SC for diff vendors/providers, storage types.

---

* Defaults
```bash
controlplane:~$ kubectl get sc
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  28d

# In Minikube there is built-in storage class standard.
$ kubectl get storageclass
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  7d2h
```


---

#### **Why Is a Storage Class Required?**

1. Simplifies the storage lifecycle by automating PV creation using dynamic provisioning.  
2. Offers flexibility to define and manage multiple storage tiers.  
3. Optimizes storage resource allocation, especially in environments spanning multiple Availability Zones (AZs).

> StorageClass takes over the role of provisioning PVs dynamically, replacing many of the static configurations you used to define in PVs manually. But not everything from PV moves into the StorageClass—some things like **access modes, size, volumeMode** still come from PVC.

---

### **Example Storage Classes**

Below are two examples of AWS EBS Storage Classes, demonstrating how multiple classes can coexist in the same cluster:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc-gp3  # Name of the StorageClass for AWS EBS gp3 volumes.
provisioner: ebs.csi.aws.com  # Specifies the CSI driver for AWS EBS.
parameters:
  type: gp3  # Defines the volume type as gp3 (general purpose SSD with configurable performance).
reclaimPolicy: Delete  # Deletes the provisioned volume when the PVC is deleted.
volumeBindingMode: WaitForFirstConsumer  # Delays volume creation until the Pod is scheduled.
```

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc-io1  # Name of the StorageClass for AWS EBS io1 volumes.
provisioner: ebs.csi.aws.com  # Specifies the CSI driver for AWS EBS.
parameters:
  type: io1  # Defines the volume type as io1 (high-performance SSD).
reclaimPolicy: Delete  # Deletes the provisioned volume when the PVC is deleted.
volumeBindingMode: WaitForFirstConsumer  # Ensures the volume is created in the same AZ as the Pod.
```
---

1. **Reclaim Policy**:
   - The `Delete` reclaim policy ensures that dynamically provisioned volumes are automatically cleaned up when their corresponding PVCs are deleted.  
   - This prevents orphaned resources and is the most common choice for dynamically provisioned storage.

2. **WaitForFirstConsumer**:

![Alt text](/images/27d.png)

   - In a Kubernetes cluster spanning multiple Availability Zones (AZs), **EBS volumes and EC2 instances are AZ-specific resources**.  
   - If a volume is immediately provisioned in one AZ when a PVC is created, and the Pod using the PVC is scheduled in another AZ, the volume cannot be mounted.  
   - The `WaitForFirstConsumer` mode ensures that the volume is created **only after the Pod is scheduled**, ensuring both the Pod and the volume are in the same AZ.  
   - This prevents inefficiencies and reduces unnecessary costs for resources provisioned in the wrong AZ.

---

### **Dynamic Provisioning in Action**

Let’s see how the `ebs-sc-gp3` Storage Class is used with a PVC, a dynamically provisioned PV, and a Pod.

#### Persistent Volume Claim (PVC)
The PVC requests dynamic provisioning by referencing the `ebs-sc-gp3` Storage Class.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-csi-pvc  # Name of the PVC to be used by Pods.
spec:
  accessModes:
    - ReadWriteOnce  # The volume can be mounted as read-write by a single node.
  resources:
    requests:
      storage: 10Gi  # Minimum storage capacity requested.
  storageClassName: ebs-sc-gp3  # References the gp3 StorageClass for dynamic provisioning.
```

#### Persistent Volume (PV)
This is an example of a PV **dynamically** created by the CSI driver when the above PVC is applied.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ebs-csi-pv  # Name of the dynamically provisioned Persistent Volume.
spec:
  capacity:
    storage: 10Gi  # Defines the storage capacity for the volume.
  volumeMode: Filesystem  # Specifies the volume is presented as a filesystem (default mode).
  accessModes:
    - ReadWriteOnce  # Restricts volume to a single node for read-write operations.
  persistentVolumeReclaimPolicy: Delete  # Automatically deletes the volume when the PVC is deleted.
  storageClassName: ebs-sc-gp3  # Matches the StorageClass that provisioned this PV.
  csi:
    driver: ebs.csi.aws.com  # The AWS EBS CSI driver responsible for provisioning this volume.
    volumeHandle: vol-0abcd1234efgh5678  # Identifies the volume in the AWS backend.
    fsType: ext4  # The filesystem type for the volume.
```

#### Pod Using PVC
The Pod dynamically mounts the volume provisioned by the PVC.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ebs-csi-pod  # Name of the Pod.
spec:
  containers:
    - name: app-container  # Name of the container in the Pod.
      image: nginx  # The container image to run.
      volumeMounts:
        - mountPath: /usr/share/nginx/html  # Mounts the volume at this path inside the container.
          name: ebs-storage  # References the volume defined in the Pod spec.
  volumes:
    - name: ebs-storage  # Volume name referenced in the container's volumeMounts.
      persistentVolumeClaim:
        claimName: ebs-csi-pvc  # Links the volume to the PVC created earlier.
```
![](/images/image2.png)
![](/images/image3.png)

#### **Key Takeaways**
- Storage Classes simplify storage management in Kubernetes, allowing dynamic provisioning of Persistent Volumes based on application needs.  
- The `reclaimPolicy: Delete` ensures proper cleanup of volumes once they are no longer needed.  
- The `WaitForFirstConsumer` binding mode optimizes placement and ensures resources like EBS volumes and Pods are aligned in multi-AZ environments.  
- By combining Storage Classes, PVCs, and dynamic provisioning, Kubernetes provides a powerful and flexible storage solution for managing workloads efficiently. 

---
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Delete
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  storageClassName: fast-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

---

### **Demo: Storage Class**

#### **Step 1: Reapply the Storage Class**
Before proceeding with the demo, we need to restore the `StorageClass` configuration that we backed up (`sc.yaml`). Run the following command to reapply it:

```bash
kubectl apply -f sc.yaml
```

This re-establishes the default `standard` StorageClass in your KIND cluster.

---

#### **Step 2: Create the PersistentVolumeClaim (PVC)**

Below is the YAML to create a PVC. It requests storage but does not explicitly reference any StorageClass:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc  # Name of the PersistentVolumeClaim
spec:
  accessModes:
    - ReadWriteOnce  # The volume can be mounted as read-write by a single node.
  resources:
    requests:
      storage: 2Gi  # Requests a minimum of 2Gi storage capacity.
```

**Key Explanation**:
- Even though we didn’t specify a StorageClass, Kubernetes defaults to using the `standard` StorageClass (if one is configured as the default).  
- The **status of the PVC** will remain as **"Pending"** initially since no Persistent Volume (PV) is created at this point.

To understand why the PVC is pending, describe the StorageClass with:
```bash
kubectl describe sc standard
```

You’ll see that the `standard` StorageClass is configured as default:
```yaml
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

#### **Step 3: Understand VolumeBindingMode**
The `WaitForFirstConsumer` mode plays a critical role:
- It delays PV creation **until a Pod is scheduled**, ensuring cost optimization and proper resource placement.  
- For example, in multi-AZ environments like AWS, if the PVC triggers volume creation in **AZ-1** but the Pod is scheduled in **AZ-2**, the volume won’t be accessible. `WaitForFirstConsumer` avoids this by creating the volume **only after a Pod is scheduled**, ensuring both the Pod and volume are in the same AZ.


#### **Step 4: Create a Pod Using the PVC**

Below is the YAML to create a Pod that uses the PVC:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod  # Name of the Pod
spec:
  containers:
    - name: nginx-container  # Container name
      image: nginx  # The container image to use
      volumeMounts:
        - mountPath: /usr/share/nginx/html  # Mounts the volume to this path in the container
          name: persistent-storage  # References the volume defined in the Pod
  volumes:
    - name: persistent-storage  # Name of the volume
      persistentVolumeClaim:
        claimName: example-pvc  # Links the PVC to the Pod volume
```

**Key Explanation**:
- Once the Pod is created, Kubernetes finds the PVC (`example-pvc`) and provisions a PV using the default `standard` StorageClass.  
- The PVC status changes to **Bound**, and a new PV is created and attached to the Pod.

#### **Step 5: Verify the Status**

Run the following commands to check the status of PVs and PVCs:

1. **Check PVs**:
   ```bash
   kubectl get pv
   ```
   Example output:
   ```
   NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS   AGE
   pvc-24d1f4ee-d3f8-40eb-8120-21f232087a19   2Gi        RWO            Delete           Bound    default/example-pvc   standard       6m
   ```

2. **Check PVCs**:
   ```bash
   kubectl get pvc
   ```
   Example output:
   ```
   NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
   example-pvc   Bound    pvc-24d1f4ee-d3f8-40eb-8120-21f232087a19   2Gi        RWO            standard       6m
   ```
- Always create a PV with the Same size as PVC not diff

### **Key Takeaways**

1. **Default StorageClass**:
   - If no StorageClass is specified in the PVC, Kubernetes uses the default StorageClass (`standard`, in this case).  
   - The `is-default-class` annotation ensures it acts as the default.

2. **VolumeBindingMode (`WaitForFirstConsumer`)**:
   - Prevents PV creation until a Pod is scheduled, optimizing resource placement and cost in multi-AZ environments.

3. **Reclaim Policy (`Delete`)**:
   - Automatically deletes PVs once their associated PVCs are deleted, preventing storage clutter.

By following these steps, you can understand how dynamic provisioning works in Kubernetes with StorageClasses, PVCs, and Pods.

---

##### **SAN vs NAS — Explained**

* **SAN (Storage Area Network)**
  * Connects storage devices (disk arrays, SSDs) to servers using a **dedicated high-speed storage network**.
  * Provides **block-level storage**.
    * Meaning: it gives the server a **raw disk/LUN**, similar to plugging in a local hard drive.
  * Operating systems or applications (e.g., databases) must **format** and **manage** the storage.
  * Used when:
    * High performance is required
    * Low latency needed
    * Applications need raw block storage (Oracle DB, VMware, etc.)

  **Think of SAN like:**
    * "Here is a raw hard drive. Do whatever you want — format it, mount it, use it."

* **NAS (Network Attached Storage)**
  * Storage system connected over a **normal IP network** (Ethernet).
  * Provides **file-level storage**.
    * Meaning: it shares **file systems** over the network (NFS, SMB).
  * Multiple clients can access these files at the same time.
  * Used for:
    * File sharing
    * Home directories
    * Backups
    * Media servers
  
  **Think of NAS like:**
    * "Here is a shared folder you can access over the network."

* **Key Differences (Quick)**

  | Feature     | SAN                           | NAS                           |
  | ----------- | ----------------------------- | ----------------------------- |
  | Access type | Block-level                   | File-level                    |
  | Protocols   | iSCSI, Fibre Channel          | NFS, SMB                      |
  | Network     | Dedicated storage network     | Standard IP network           |
  | Performance | Very high                     | Moderate                      |
  | Used for    | Databases, VMs, critical apps | File sharing, general storage |

---

## **File Storage**

* Stores data **as files** organized in **folders/directories**.
* Works like how files are stored on your computer (hierarchical structure).
* Accessed via **file system protocols** such as:

  * **NFS** (Network File System – Linux/Unix)
  * **SMB / CIFS** (Windows)


| Feature         | Description                                     |
| --------------- | ----------------------------------------------- |
| **Structure**   | Hierarchical (folders, subfolders, files)       |
| **Access**      | Through file paths (`/home/user/docs/file.txt`) |
| **Metadata**    | Limited (filename, size, permissions)           |
| **Scalability** | Limited to one server or cluster                |
| **Performance** | Good for shared files, slower for large data    |
| **Examples**    | NFS, SMB, Amazon EFS, Google Filestore          |

* Best for:
  * Shared network drives
  * User home directories
  * Content management systems (CMS)
  * Development environments



## **Block Storage**

* Data stored in **fixed-size blocks** (e.g., 512B, 4KB).
* Each block has an address, but **no metadata or file structure**.
* The OS formats and manages it as a filesystem.
* Accessed at **low-level** via block devices (like disks).
* Examples:
  * `/dev/sda` in Linux
  * iSCSI, Fibre Channel, NVMe over network


| Feature         | Description                                    |
| --------------- | ---------------------------------------------- |
| **Structure**   | Raw blocks, no hierarchy                       |
| **Access**      | By block address (via OS or application)       |
| **Metadata**    | None (only OS knows file structure)            |
| **Scalability** | Vertical (attached to one instance)            |
| **Performance** | High IOPS and low latency                      |
| **Examples**    | AWS EBS, Google Persistent Disk, iSCSI volumes |

* Best for:
  * Databases (MySQL, PostgreSQL, Oracle)
  * Virtual machine disks
  * Transaction-heavy workloads
  * Filesystems (ext4, XFS) built on top of it


## **Object Storage**
* Stores data as **objects** with:
  * Data (the content)
  * Metadata (custom + system)
  * Unique ID (used for retrieval)

* **Flat structure** (no folders) — all objects stored in a **bucket**.

* Not mounted to pod
* Accessed via **HTTP/REST APIs**, not mounted as a filesystem.
* Example API calls or SDKs:
  * `PUT /bucket/object`
  * `GET /bucket/object`


| Feature         | Description                            |
| --------------- | -------------------------------------- |
| **Structure**   | Flat (no hierarchy)                    |
| **Access**      | API-based (HTTP/S3)                    |
| **Metadata**    | Rich and customizable                  |
| **Scalability** | Infinitely scalable (horizontal)       |
| **Performance** | High throughput, not low-latency       |
| **Examples**    | Amazon S3, Google Cloud Storage, MinIO |

* Best for:
  * Cloud-native applications
  * Backups and archives
  * Media storage (images, videos)
  * Big Data, analytics data lakes

<br>

### Summary Comparison Table

| Feature              | **File Storage**             | **Block Storage**               | **Object Storage**                |
| -------------------- | ---------------------------- | ------------------------------- | --------------------------------- |
| **Structure**        | Hierarchical (files/folders) | Blocks                          | Flat (objects)                    |
| **Access Protocols** | NFS, SMB                     | iSCSI, FC                       | HTTP, REST, S3                    |
| **Metadata Support** | Basic                        | None                            | Extensive (custom)                |
| **Performance**      | Medium                       | High                            | High throughput (not low latency) |
| **Scalability**      | Moderate                     | Limited                         | Massive (horizontal)              |
| **Persistence**      | Yes                          | Yes                             | Yes                               |
| **Use Case**         | Shared file access           | Databases, VMs                  | Backups, media, big data          |
| **Example Services** | Amazon EFS, Azure Files      | AWS EBS, Google Persistent Disk | AWS S3, Azure Blob, MinIO         |

---

#### Troubleshooting Persistent Storage
* PVC Pending
  * No matching PV
  * Wrong StorageClass
  * Insufficient storage size
* Pod stuck in ContainerCreating
  * PVC not Bound
    * Use:
      ```bash
      kubectl describe pod <pod>
      ```
---

Below is **the complete, crystal-clear guide** to **CloudFront Custom Error Pages** — including **concept**, **use cases**, **all HTTP codes supported**, **step-by-step GUI configuration**, **infrastructure behavior**, and **Terraform / CLI examples**.

---

# ✅ **What Are CloudFront Custom Error Pages?**

CloudFront normally shows **its own default error pages** (ugly XML page) when:

* Your **origin (S3/ALB/EC2)** sends an error
* CloudFront **times out**
* Permission issue
* Missing file
* Origin returns **HTTP 4xx or 5xx**

Custom Error Pages allow you to **replace CloudFront’s default error pages with:**

* A custom **HTML file**
* A custom **fallback URL**
* A specific **cache duration**
* A custom **response code** sent to the client

---

# 🚀 **Why Use Custom Error Pages?**

* Give friendly user-facing messages
* Hide backend errors (security & UX)
* Send branding instead of CloudFront XML page
* Unified error handling across microservices
* Redirect `/404.html`, `/503.html`, `/maintenance.html`

---

# 🔥 **Supported Error Codes**

CloudFront can customize:

| Error Type              | Codes                        |
| ----------------------- | ---------------------------- |
| **Client Errors (4xx)** | 400, 403, 404, 405, 414, 416 |
| **Server Errors (5xx)** | 500, 501, 502, 503, 504      |

---

# 🧠 **How It Works Internally**

Example:

1. User hits `https://d111.cloudfront.net/page.html`
2. Origin responds **404 Not Found**
3. CloudFront detects this and checks **custom-error rules**
4. If matched:

   * CloudFront fetches `/errors/404.html` from your S3 origin
   * CloudFront returns **either:**

     * HTTP 404 **(original)** OR
     * HTTP 200 **(custom response code)**

---

# 🛠 **STEP-BY-STEP: Create Custom Error Page (AWS Console)**

### 1️⃣ Upload Custom Error HTML File

If using **S3 origin**:

Inside bucket, upload:

```
errors/404.html
errors/503.html
errors/maintenance.html
```

Make sure CloudFront OAC has access.

---

### 2️⃣ Go to CloudFront → Your Distribution → **Error Pages** → Create

### Example #1 → Custom 404 Page

```
HTTP Error Code: 404
Customize Error Response: Yes
Response Page Path: /errors/404.html
HTTP Response Code: 404
TTL (seconds): 10       # how long to cache this error
```

### Example #2 → Maintenance Mode (503 → return 200)

```
HTTP Error Code: 503
Customize Error Response: Yes
Response Page Path: /maintenance.html
HTTP Response Code: 200
TTL: 300
```

---

# 🍭 **Behavior Options Explained**

### **Response Page Path**

Where the custom page exists inside origin:

```
/errors/404.html
/errors/5xx.html
/maintenance/index.html
```

### **HTTP Response Code**

| What you choose            | Meaning                                                   |
| -------------------------- | --------------------------------------------------------- |
| **Match Origin (default)** | Browser receives same error (404/503)                     |
| **200 OK**                 | User sees error page but browser thinks request succeeded |
| **302 Redirect**           | Redirect user to another path                             |

### **Error Cache TTL**

CloudFront caches errors too.

```
TTL = 0 → no caching (top correctness)
TTL = 10–300 → good compromise
TTL = 300+ → fast but stale
```

---

# 🧪 **Testing Custom Error Pages**

### Test 404

```
curl -I https://dxxxx.cloudfront.net/notfound.html
```

Look for:

```
X-Cache: Error from cloudfront
```

### Test maintenance `/503.html`

Force maintenance from origin → CloudFront should serve `/maintenance.html`.

---

# 💡 Best Practices (Production)

* Always configure **503 → maintenance.html**
* Keep error pages in a dedicated folder `/errors/`
* Use `"Response Code = 200"` for maintenance mode pages
* Set low TTL during development (1–10 seconds)
* Set higher TTL in prod (120–600 seconds)
* Invalidate error pages after modifying them

---

# 🧰 Terraform Example (Full Block)

Add inside `aws_cloudfront_distribution`:

```hcl
custom_error_response {
  error_code            = 404
  response_page_path    = "/errors/404.html"
  response_code         = 404
  error_caching_min_ttl = 10
}

custom_error_response {
  error_code            = 503
  response_page_path    = "/maintenance.html"
  response_code         = 200
  error_caching_min_ttl = 300
}
```

---

# 🔧 AWS CLI Example

### Create 404 error rule

```bash
aws cloudfront update-distribution \
  --id EXXXX \
  --distribution-config file://dist.json \
  --if-match E2XXXX
```

Inside JSON, include:

```json
"CustomErrorResponses": {
  "Quantity": 1,
  "Items": [
    {
      "ErrorCode": 404,
      "ResponsePagePath": "/errors/404.html",
      "ResponseCode": "404",
      "ErrorCachingMinTTL": 10
    }
  ]
}
```

---

# 📦 Common Use Cases & Solutions

### ✅ **Hosting single-page apps (React/Vue/Angular)**

404 should route to `/index.html`:

```
404 → /index.html
Response Code: 200
```

### ✅ **S3 private bucket – prevent XML errors**

Replace S3 XML access denied with friendly HTML.

### ✅ **Maintenance Window**

```
503 → /maintenance.html
Return 200 OK
```

---

# 🎉 If you want, I can provide:

✔ A complete **CloudFront + S3 + OAC + Custom Error Pages** Terraform module
✔ A real-world setup example for **SPA hosting**
✔ A CloudFront **maintenance-mode toggle** script
✔ A version with **multiple origins path-based routing + custom errors**

Just tell me **what setup you want next**.



---

Nice — I’ll do two things in one answer:

1. give a ready-to-run **Python Flask application** (implements the same endpoints & behaviour Gaurav demoed), with Dockerfile + run instructions;
2. explain **every concept from the transcript** (CloudFront + app interactions, caching, headers, origin protection, pagination, cache-key, TTLs, testing) in clear, compact bullet points so you can use it as a reference.

No fluff — everything practical and copy-paste ready.

---

* Flask app: single-file `app.py` implementing:

  * `/` simple health
  * `/1m` returns dynamic UUID and `Cache-Control: max-age=60`
  * `/2m` same but `max-age=120`
  * `/users` paginated JSON (query params `page`, `size`)
  * `/custom-header` requires a specific header (example `Request-From: CloudFront-Head`) — returns 403 if missing
  * adds a dynamic `X-Request-UUID` on each response so you can see cache hits/misses
* Dockerfile + requirements so you can build and run in EC2 (or locally) exactly like the video.

```python
# app.py
from flask import Flask, request, jsonify, abort, make_response
import uuid
import time

app = Flask(__name__)

# sample users dataset
USERS = [{"id": i+1, "name": f"user_{i+1}"} for i in range(22)]

def make_uuid():
    return str(uuid.uuid4())[:8]

@app.route("/")
def index():
    uid = make_uuid()
    resp = make_response({"message": "Hello from API", "uuid": uid})
    resp.headers["X-Request-UUID"] = uid
    return resp

@app.route("/1m")
def one_min():
    uid = make_uuid()
    body = {"msg": "1 minute cache endpoint", "uuid": uid, "ts": int(time.time())}
    resp = make_response(jsonify(body))
    # Cache-Control max-age expressed in seconds (CloudFront/browser will use this unless CF overrides)
    resp.headers["Cache-Control"] = "max-age=60, public"
    resp.headers["X-Request-UUID"] = uid
    return resp

@app.route("/2m")
def two_min():
    uid = make_uuid()
    body = {"msg": "2 minute cache endpoint", "uuid": uid, "ts": int(time.time())}
    resp = make_response(jsonify(body))
    resp.headers["Cache-Control"] = "max-age=120, public"
    resp.headers["X-Request-UUID"] = uid
    return resp

@app.route("/users")
def users():
    # pagination: default page=1, size=5
    try:
        page = int(request.args.get("page", "1"))
        size = int(request.args.get("size", "5"))
    except ValueError:
        page = 1; size = 5
    if page < 1: page = 1
    if size < 1: size = 5

    start = (page - 1) * size
    end = start + size
    subset = USERS[start:end]
    resp_body = {
        "page": page,
        "size": size,
        "total": len(USERS),
        "users": subset,
        "uuid": make_uuid()
    }
    resp = make_response(jsonify(resp_body))
    # Control caching for this endpoint (example: don't cache by default)
    resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    resp.headers["X-Request-UUID"] = resp_body["uuid"]
    return resp

@app.route("/custom-header")
def custom_header():
    # Expect CloudFront to attach header "Request-From: CloudFront-Head"
    allowed_value = "CloudFront-Head"
    header_val = request.headers.get("Request-From")
    if header_val != allowed_value:
        # deny direct access from browser / external clients
        abort(make_response(jsonify({"error": "Forbidden - missing required header"}), 403))
    body = {"msg": "Accessed via CloudFront", "uuid": make_uuid()}
    resp = make_response(jsonify(body))
    resp.headers["Cache-Control"] = "max-age=30, public"
    resp.headers["X-Request-UUID"] = body["uuid"]
    return resp

# helpful endpoint to inspect headers received by origin
@app.route("/inspect-headers")
def inspect_headers():
    headers = {k:v for k,v in request.headers.items()}
    headers["X-Request-UUID"] = make_uuid()
    return jsonify(headers)

if __name__ == "__main__":
    # listen on 0.0.0.0 so EC2/public IP can be used
    app.run(host="0.0.0.0", port=3000)
```

```dockerfile
# Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 3000
CMD ["gunicorn", "--bind", "0.0.0.0:3000", "app:app", "--workers", "2", "--threads", "4"]
```

`requirements.txt`:

```
Flask==2.2.5
gunicorn==20.1.0
```

* Build & run locally or on EC2:

  * `docker build -t cloudfront-sample-api:latest .`
  * `docker run -d -p 3000:3000 --name cf-api cloudfront-sample-api:latest`
  * Test: `curl http://<EC2_PUBLIC_IP>:3000/1m` and `curl http://<EC2_PUBLIC_IP>:3000/users?page=2&size=3`

---

* CloudFront <-> App concepts (detailed, practical):

  * `Cache-Control` header:

    * this header returned by your origin tells browsers and caches (including CloudFront) how long content is fresh.
    * `Cache-Control: max-age=60` → 60 seconds freshness. CloudFront will treat this as TTL unless CloudFront cache policy overrides it (see below).
    * use `no-cache` / `no-store` for dynamic endpoints you never want cached.

  * CloudFront TTLs & Cache Policy:

    * CloudFront caching behavior is controlled by distribution *Cache Behavior* + optional *Cache Policy*.
    * three TTLs in CF: `Minimum TTL`, `Maximum TTL`, `Default TTL`.
    * CloudFront obeys `Cache-Control` from origin when `Cache Policy` set to "Use origin cache headers" (or when you forward origin headers appropriately).
    * if you choose "Cache based on origin" CF will use the origin `Cache-Control`; otherwise CF's TTLs can override or be used.

  * Cache hits vs misses:

    * On first request CF edge asks origin → **MISS**; origin response gets cached at that edge.
    * Subsequent requests within TTL → **HIT** (served from edge; origin not contacted).
    * After TTL expires → next request is **MISS** again and CF fetches origin and caches new response.

  * CloudFront cache key:

    * defines what CF uses to differentiate cached objects (path + optionally query string + headers + cookies).
    * if you need different cached responses for different query params (like `page`/`size`), you must include query strings in cache key (enable forwarding of query strings in behavior).
    * if you want to treat `/users?page=1` and `/users?page=2` as the same cached object, *do not* forward query string — but that causes wrong results for paginated APIs.

  * Forwarding query strings:

    * for paginated API `/users?page=x&size=y` forward query strings so CF cache key includes them (Cache Behavior → "Forward query strings").
    * beware: forwarding query strings multiplies cache items and increases edge storage/requests to origin.

  * Forwarding headers:

    * you may forward specific headers (e.g., `Request-From`) or choose to *whitelist* headers necessary to your app logic.
    * forwarding many headers reduces cache efficiency (fewer cache hits).

  * Origin custom headers:

    * CloudFront supports adding an *Origin Custom Header* that CloudFront attaches to origin requests (configured on the origin).
    * use this to protect your origin: have the origin require `Request-From: CloudFront-Head` and only accept requests containing that header.
    * combine with security group rules that allow only CloudFront IP ranges or implement OAI/OAC for S3 origins.
    * origin custom header example: name=`Request-From`, value=`CloudFront-Head` → app checks header, returns 403 if missing.

  * Protect origin (practical options):

    * security-group + CloudFront IP ranges (downloads from AWS JSON of IP ranges) — maintenance heavy.
    * origin custom header + origin policy (works but header can be faked if someone talks directly to origin IP unless security-group restricts access).
    * for S3 origins use **Origin Access Control (OAC)** or OAI to make bucket private and allow CF to access on your behalf.
    * use ALB + WAF + check custom headers + origin SG to block direct access and accept only CloudFront.

  * Cache-Control vs CloudFront TTL interplay:

    * If you want origin to *define* TTL, use cache policy: **"Use origin cache headers"**.
    * If you want CloudFront to control TTL regardless of origin headers, set CF TTLs explicitly in the behavior.
    * Example: origin `Cache-Control: max-age=60` & CF default TTL=3600 will still often use origin header if "Use origin headers" is set; if CF default overrides, CF may keep cached object longer.

  * Invalidations:

    * If you update origin content and want CF edges to pick changes immediately, create an **invalidaton** for the paths (e.g., `/*` or `/index.html`).
    * invalidations take time to propagate and have a cost (first 1000 invalidations per month usually free — check pricing).

  * Custom error page:

    * CloudFront can be configured to map HTTP 403/404/500 responses to custom error pages (from origin or S3).
    * useful for user-friendly messages when geo-blocked or forbidden.

  * Cache-Control best-practices for APIs:

    * static assets: long `max-age`, use versioned filenames
    * dynamic endpoints: `no-cache` or short `max-age`, unless you control content freshness
    * paginated or query-based endpoints: forward query string and set appropriate caching (or no-cache)
    * introduce ETag or Last-Modified for conditional requests (304 Not Modified) when possible

  * Why CloudFront might appear to “misbehave” with query strings:

    * CF caches by key — if query strings are not forwarded then `/users?page=1` and `/users?page=2` will return same cached content (wrong).
    * fix by enabling query string forwarding in behavior and optionally selecting which query parameters to include.

  * Headers & security:

    * adding a check for `Request-From` in the app enforces that only requests forwarded by CF (that attach header) get processed.
    * combine with SG restrictions: allow HTTP only from CloudFront IP ranges (or only allow ALB/ELB -> internal traffic).
    * for stronger security, use OAuth, signed URLs, or signed cookies.

  * Testing & debugging:

    * Use browser DevTools → Network tab to inspect response headers:

      * look for `X-Cache: Hit from cloudfront` or `Miss from cloudfront`
      * inspect `Cache-Control`, `Age`, `X-Request-UUID`
    * Use `curl -I` to inspect headers quickly:

      * `curl -I https://<cloudfront-domain>/1m`
    * To mimic CloudFront origin request header, `curl -H "Request-From: CloudFront-Head": "http://<origin>:3000/custom-header"`

  * Pagination design:

    * default `page=1` and `size=5` are good defaults
    * ensure unchanged cache behavior: typically don't cache paginated endpoints unless keyed by page/size
    * when caching, include `page` & `size` in cache key (CloudFront forwarding) so each page is cached separately

  * Dynamic UUID behavior:

    * each new origin request produces a new UUID — useful to demonstrate cache misses (origin called) vs hits (UUID unchanged served from edge)
    * `X-Request-UUID` tells you origin-generated value — if it changes, the request reached origin; if same across requests within TTL, it was served from cache

  * Deploy flow summary:

    * launch EC2, open SG ports (22 SSH, 3000 or 80/443 depending)
    * install Docker, build/pull image, run container
    * create CloudFront distribution:

      * origin → your EC2 public DNS or ALB
      * cache behavior: set path patterns (`/api/*`, `/images/*`) with different cache policies
      * for `/users` forward query string and set `Cache-Control` policy or no-cache
      * set origin custom header `Request-From: CloudFront-Head`
      * deploy distribution, then test via CF domain
    * optionally lock down origin so only CloudFront can reach it (via SG or private origin + ALB and CF with OAC)

  * Common pitfalls:

    * forgetting to forward query strings for dynamic endpoints → wrong page served
    * forwarding too many headers → low cache hit ratio
    * relying on CloudFront TTL defaults inadvertently causing stale content
    * not protecting origin → direct access bypasses CloudFront header check

---

* Quick cloudfront configuration checklist for this app:

  * create behavior for `/1m`:

    * Path pattern: `/1m`
    * Cache policy: use origin headers (or default) → origin `max-age=60` will be used
  * create behavior for `/2m`:

    * similarly
  * create behavior for `/users`:

    * Path pattern: `/users*`
    * Forward Query Strings: Yes
    * Cache policy: `CachingDisabled` or `Origin` depending on needs
  * create behavior for `/custom-header`:

    * ensure CF origin custom header `Request-From: CloudFront-Head` is set on origin config
    * optionally set `Cache-Control` short TTL
  * origin settings:

    * add custom header `Request-From: CloudFront-Head`
    * if origin is EC2, tighten security group to limit access (for production prefer ALB + internal SG)

---

* Example `curl` tests:

  * direct origin request (should fail `/custom-header`):

    * `curl -i http://<EC2_IP>:3000/custom-header`
    * expect `403 Forbidden`
  * origin with header (simulate CloudFront):

    * `curl -i -H "Request-From: CloudFront-Head: CloudFront-Head" http://<EC2_IP>:3000/custom-header`
    * expect `200` + JSON
  * via CloudFront, check cache:

    * `curl -I https://<CF_DOMAIN>/1m` → get `Cache-Control: max-age=60` and `X-Cache: Miss from cloudfront` (first time)
    * repeat `curl -I` quickly → `X-Cache: Hit from cloudfront` and `X-Request-UUID` same as previous

---

* Optional improvements you can implement quickly:

  * add `ETag`/`Last-Modified` to endpoints to support conditional GETs and smaller responses (304 Not Modified)
  * use `gunicorn` + `nginx` reverse proxy for production robustness
  * switch to ALB behind CF to avoid exposing instance IP and allow internal-only origin
  * deploy via Terraform for reproducible CF + origin setup

---

If you want, I can:

* provide a ready-to-run `docker-compose.yml` that builds and runs the Flask app and a small Nginx (optional);
* give the exact CloudFront GUI steps (or Terraform HCL) to create the distribution and add the origin custom header and cache behaviors;
* generate sample `curl` commands and expected outputs for each scenario.

Which of those would you like next?


---


Here is **EVERY concept explained in a clean, simple, structured, professional way** (based on the entire Hindi transcript you shared).

I am giving you **all concepts in bullet points** (your preferred format), but very detailed and in perfect English — this will help you understand CloudFront + API behavior exactly like Gaurav explained.

---

# ✅ **COMPLETE CONCEPTS FROM THE VIDEO — EXPLAINED CLEANLY**

---

# **1. EC2 Application Behavior**

Your backend EC2 application returns:

* `/1m` → random UUID + cache headers for **60 seconds**
* `/2m` → random UUID + cache headers for **120 seconds**
* `/users` → paginated data (page & size supported)
* `/custom-header` → only works when a specific custom header is received
* Any direct access without the header → returns **403 Forbidden**

This backend is built to **demonstrate caching, header validation, and query parameter behavior**.

---

# **2. CloudFront + Backend Interaction**

When you put CloudFront in front of the EC2 API:

* CloudFront **caches responses** based on the **cache-control** headers returned by your API.
* CloudFront does **NOT** understand UUID changes — it will cache the old one until TTL expires.

Example:

* API sends:
  `Cache-Control: public, max-age=60`
* CloudFront caches the response for **60 seconds**
* During those 60 seconds:
  – Your EC2 returns NEW UUID every request
  – CloudFront returns OLD UUID (cached)
  → This is **expected behavior**.

---

# **3. Why CloudFront Shows Same UUID?**

Because:

* CloudFront caches the response using your backend headers.
* A request first checks CloudFront's cache; if hit → responds directly.
* Only after TTL expires → CloudFront fetches a new value from EC2.

So CloudFront behaves exactly based on:

* `Cache-Control` headers
* `ETag` (if present)
* Cache policy settings

This concept is **origin cache TTL**.

---

# **4. "MISS FROM CloudFront" vs "HIT FROM CloudFront"**

These appear in the response headers:

* **MISS** → CloudFront forwarded request to EC2 (origin)
* **HIT** → CloudFront served response from cache (faster)
* **REFRESH_HIT** → cache refreshed due to TTL expiry

This helps track caching behavior.

---

# **5. Adding Custom Header in CloudFront to Secure Your Backend**

Your backend returns:

* **403** if accessed directly
* **200 OK** only if the request includes a specific header

CloudFront Origin settings allow you to add headers to each request:

Example:

Header Name: `request-from`
Value: `cloudfront-head`

CloudFront → attaches header → Backend allows request
Client/Browser → no header → Backend denies request

This gives **origin-level security** without allowing public access.

---

# **6. Why EC2 Direct Access is Blocked**

Backend checks for:

```js
if request.headers['request-from'] != 'cloudfront-head':
    return 403
```

So:

* Browser → no header → **blocked**
* CloudFront → header injected → **allowed**

This ensures **only CloudFront can access the backend**.

---

# **7. Example Use Case for This Security**

This prevents:

* direct API attacks
* DDoS on EC2
* bypassing CloudFront caching
* avoiding geographic restrictions
* hiding direct server IPs

CloudFront becomes the **only allowed pathway**.

---

# **8. Query Parameter Problem (Pagination Issue)**

Backend supports queries:

```
/users?page=1&size=5
/users?page=3&size=2
```

But CloudFront DOES NOT forward query parameters unless you configure a **Cache Policy** that includes:

* Query strings
* Headers
* Cookies (if needed)

If query parameters are **not forwarded**, CloudFront sees all URLs as same:

```
/users       <-- CloudFront treats ALL as same
/users?page=1
/users?page=2
/users?page=3
```

Meaning:

* CloudFront always sends the **same cached response**
* All `page` values return the same output → **wrong behavior**

This is WHY pagination breaks.

This exact problem will be fixed using a cache policy like:

```
QueryStringBehavior: all
```

---

# **9. What must be configured to fix pagination?**

You must configure CloudFront to:

* **Forward Query Strings**
* **Include Query Strings in Cache Key**

Otherwise CloudFront will not differentiate pages.

---

# **10. Why CloudFront Must Be “Public” Initially**

During explanation:

* The instructor keeps EC2 public temporarily **to demonstrate behavior**
* Later will restrict EC2 to **only allow CloudFront IPs**

This is common while learning/testing.

---

# **11. Why CloudFront Deployment Takes 2–3 Minutes**

Because CloudFront:

* distributes configuration to **edge locations worldwide**
* creates/update caches
* syncs behavior rules globally
* takes time to propagate

This is called **CloudFront global propagation delay**.

---

# **12. CloudFront Cache Policies Were Used**

You used a custom cache policy to:

* respect origin cache-control headers
* ensure CloudFront caches based on backend rules

Cache policy determines:

* TTL
* Headers forwarded
* Query params forwarded
* Cookies forwarded
* Cache key generation

CloudFront caching behavior = **origin headers + CloudFront cache policy**.

---

# **13. Cache-Control Header Explanation**

Backend sets:

```
Cache-Control: public, max-age=60
```

Meaning:

* **public** → CDN (CloudFront) is allowed to cache
* **max-age=60** → response valid for 60 seconds

CloudFront strictly follows this.

If backend uses:

```
Cache-Control: private
```

→ CloudFront will NOT cache at all.

---

# **14. Analytics Headers That CloudFront Adds**

CloudFront adds useful headers such as:

* `X-Cache: Hit from CloudFront`
* `X-Cache: Miss from CloudFront`
* `Via`
* `Request-ID`

These help track caching behavior.

---

# **15. Summary of the 3 Use Cases in the Video**

### **Use Case 1 — Short/Long Caching**

* `/1m` → cached 60 seconds
* `/2m` → cached 120 seconds
* CloudFront follows backend TTL.

### **Use Case 2 — Custom Header Security**

* CloudFront adds header → backend allows
* Browser direct → denied
* Prevents bypassing CloudFront.

### **Use Case 3 — Query Parameter Issue**

* Pagination breaks because CloudFront doesn’t forward query params
* Requires a proper cache policy to forward & cache by params.

---

# ✔️ **If You Want — I Can Create the Perfect Python Flask Application Matching This Behavior**

It will include:

* `/1m`
* `/2m`
* `/users?page=…&size=…`
* `/custom-header`
* randomized UUID responses
* cache-control headers exactly like video

Would you like **100% working Flask code** for this demo?


---


