### References:
- [Day 27: Kubernetes Volumes | Persistent Storage | PV, PVC, StorageClass, hostPath DEMO](https://www.youtube.com/watch?v=C6fqoSnbrck&ab_channel=CloudWithVarJosh)


### Evolution of Storage in Kubernetes: From In-Tree to CSI Drivers
![Alt text](/images/27a.png)

Managing **persistent storage** in Kubernetes has come a long way. Initially, storage drivers were built directly into Kubernetes' core codebase, known as **in-tree volume plugins**. Over time, this tightly coupled model proved limiting, leading to the adoption of the **Container Storage Interface (CSI)**—a modular and extensible solution for storage integration.

This write-up explores the transition from in-tree plugins to CSI drivers and explains where commonly-used storage types fit into Kubernetes today.


#### 1. In-Tree Volume Plugins: The Legacy Model

In-tree volume plugins were integrated directly into Kubernetes' codebase. Adding or updating these plugins required modifying Kubernetes itself, resulting in several drawbacks:
- Maintenance was cumbersome and tied to Kubernetes release cycles.
- Vendors could not independently develop or release updates.
- Bugs in storage drivers could affect Kubernetes core functionality.

##### Examples of In-Tree Plugins:
- `awsElasticBlockStore` (AWS EBS)
- `azureDisk`, `azureFile`
- `gcePersistentDisk` (GCE PD)
- `nfs`, `glusterfs`
- `rbd` (Ceph RADOS Block Device)
- `iscsi`, `fc` (Fibre Channel)

- The way this storage system are used is upgraded using CSI drivers.

**Note:** Most in-tree plugins are deprecated and replaced with CSI drivers.

#### 2. Container Storage Interface (CSI): The Modern Standard

To address the limitations of in-tree plugins, Kubernetes adopted the **Container Storage Interface (CSI)**, developed by the **Cloud Native Computing Foundation (CNCF)**. CSI decouples storage driver development from Kubernetes core, allowing vendors to independently create and maintain their drivers.

##### Key Benefits of CSI:
- **Independent updates:** Vendors can release drivers without waiting for Kubernetes updates.
- **Faster development:** Features and fixes are delivered more quickly.
- **Flexibility:** CSI supports advanced capabilities like snapshotting, resizing, cloning, and monitoring.
- **Easy integration:** Drivers for custom use cases can be developed with ease.
- Community develop the CSI driver

##### Examples of CSI Drivers:
- AWS EBS CSI Driver: `ebs.csi.aws.com`
- GCE PD CSI Driver: `pd.csi.storage.gke.io`
- Azure Disk CSI Driver: `disk.csi.azure.com`
- Ceph CSI Driver
- OpenEBS CSI Drivers (e.g., for cStor, Jiva, etc.)
- Portworx CSI, vSphere CSI

**Note:** Starting with Kubernetes 1.21, most in-tree volume plugins were officially deprecated, and CSI became the default for handling persistent volumes.

### Why Volumes Are Needed

* Containers are **ephemeral** (temporary). If a container stops, all data in its filesystem is lost.
* Applications that need to **store state (like databases, logs, configs, or uploads)** will lose everything when the pod restarts unless volumes are used.
* Volumes solve this by **decoupling storage from the container lifecycle**.

#### **Transitioning from In-Tree Drivers**
While in-tree drivers served their purpose in the early stages of Kubernetes, they are now being deprecated. CSI plugins are the recommended approach for modern storage management. For example:

**In-Tree Driver Example**:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: in-tree-pv
  # Name of the PersistentVolume resource.
spec:
  capacity:
    storage: 10Gi
    # Defines the size of the volume. This PV provides 10Gi of storage.
  accessModes:
    - ReadWriteOnce
    # The volume can be mounted as read-write by a single node.
  awsElasticBlockStore:
    # This is the legacy in-tree volume plugin for AWS EBS.
    # It allows mounting an existing AWS EBS volume into a pod.
    volumeID: vol-0abcd1234efgh5678
    # The unique ID of the EBS volume to be mounted.
    fsType: ext4
    # The filesystem type of the volume. This must match the filesystem on the EBS volume.

```

**CSI Driver Example**:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: csi-pv
  # The name of the PersistentVolume resource.
spec:
  capacity:
    storage: 10Gi
    # Defines the storage size of the volume. This volume offers 10Gi of space.
  accessModes:
    - ReadWriteOnce
    # The volume can be mounted as read-write by only one node at a time.
  storageClassName: gp3-sc
  # The StorageClass to which this volume belongs.
  # This allows dynamic provisioning and matching with a PVC that requests 'gp3-sc'.
  csi:
    # This specifies the use of a Container Storage Interface (CSI) driver,
    # which is the recommended way to provision external storage in modern Kubernetes clusters.
    driver: ebs.csi.aws.com
    # The name of the CSI driver used for AWS EBS volumes.
    volumeHandle: vol-0abcd1234efgh5678
    # The unique ID of the EBS volume in AWS.
    # This is used by the driver to locate and attach the correct volume.
    fsType: ext4
    # The filesystem type to mount. This must match the actual filesystem on the EBS volume.

```

---

#### **Key Takeaways:**
1. **In-Tree Drivers**: These legacy solutions are tightly coupled with Kubernetes and being phased out.  
2. **CSI Plugins**: The preferred method for storage integration, offering scalability and extensibility.  
3. **Dynamic Provisioning**: CSI supports automated volume creation and lifecycle management via StorageClasses.  
4. **File, Block, and Object Storage**:
   - **File and Block Storage**: Mountable as volumes in Pods using CSI plugins.  
   - **Object Storage**: Not natively mountable; access via application-level SDKs or APIs is recommended.

---

Kubernetes supports **CSI (Container Storage Interface) plugins** for both **file (NFS)** and **block storage** options. These plugins are provided by storage vendors such as **NetApp**, **Dell EMC**, and cloud providers like **AWS**, **Azure**, and **Google Cloud Platform (GCP)**. CSI plugins enable Kubernetes Pods to access file and block storage seamlessly, offering advanced features like dynamic provisioning, snapshots, and volume resizing.

For object storage solutions like **Amazon S3**, **Azure Blob Storage**, or **Google Cloud Storage (GCS)**, Kubernetes does not natively support mounting object storage as volumes because object storage operates differently from file systems. Instead, it is **recommended to use application-specific SDKs** or APIs to interact with object storage. These SDKs allow applications to efficiently access and manage object storage for tasks such as retrieving files, uploading data, and performing operations like versioning or replication.

The distinction lies in the use case:  
- **File and Block Storage**: Designed for direct mounting and integration with Kubernetes workloads using CSI plugins.  
- **Object Storage**: Better suited for application-level access via APIs or SDKs, as it was not designed to be mounted like file systems.  

By leveraging CSI plugins for file and block storage, and SDKs for object storage, you can make the most of modern, scalable storage options tailored to your Kubernetes workloads.

> Earlier, Kubernetes supported a lot of built-in drivers, called in-tree plugins. But today, the ecosystem has fully moved to **CSI drivers**, which are the future-proof way to provision and consume persistent storage. So whatever storage you’re dealing with — AWS EBS, NFS, iSCSI — if you’re doing it the modern way, you’re doing it with a **CSI driver**.


#### Volume Types

1. **emptyDir**
   * Created when a Pod starts and deleted when the Pod stops.
   * Good for temporary storage (scratch space, caching, buffer files).
   * Example:
     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: test-vol
     spec:
       containers:
       - name: test-container
         image: nginx
         volumeMounts:
         - mountPath: /data
           name: first-volume
       volumes:
       - name: first-volume
         emptyDir: {}
     ```

---

2. **hostPath**
   * Mounts a directory/file from the **host node’s filesystem** into the pod.
   * Useful for things like container logs (`/var/logs`) or access to node-level files.
   * But ties the pod to a **specific node**, reducing portability.

     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: test-vol
     spec:
       containers:
       - name: test-container
         image: nginx
         volumeMounts:
         - mountPath: /data
           name: first-volume
       volumes:
       - name: first-volume
         hostPath:
           path: /tmp/data
     ```

---

3. **Cloud Volumes (EBS in AWS)**
   * Persistent and **independent of pod lifecycle**.
   * Must be created in the same Availability Zone as the worker node.
   * Example using **AWS EBS volume**:

     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: test-vol
     spec:
       containers:
       - name: test-container
         image: nginx
         volumeMounts:
         - mountPath: /data
           name: first-volume
       volumes:
       - name: first-volume
         awsElasticBlockStore:
           volumeID: <your-ebs-volume-id>
           fsType: ext4
     ```

---

### Limitations

* **emptyDir** → temporary only.
* **hostPath** → node-dependent, not portable.
* **EBS/Cloud volumes** → tied to specific zones, need correct setup.

---

### Multi-Node Cluster Considerations

* Pods may reschedule on another node.
* HostPath volumes **won’t follow the pod**.
* Cloud volumes (EBS, GCP PD, Azure Disk) are **attachable to nodes** when pods reschedule.

---

### Steps for Cloud Volumes (AWS EBS example)

1. Create EBS volume in AWS.

2. Attach volume ID to Pod YAML.

3. Apply YAML.

4. Verify pod mounts correctly:

   ```bash
   kubectl apply -f ebs.yaml
   kubectl exec -it test-vol -- /bin/sh
   df -h
   ```

5. If pod moves to another node → volume is re-attached.

---

✅ In short:

* **emptyDir** → temporary storage, cleared when pod ends.
* **hostPath** → maps local node dir into pod, but not portable.
* **Cloud volumes (EBS, GCP PD, Azure Disk)** → persistent storage across restarts, production-grade.

