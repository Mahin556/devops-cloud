# **CSI-Based Storage Providers (3rd-Party Integrations)**

These implement the **CSI (Container Storage Interface)** and work with any Kubernetes cluster.

### **Enterprise Storage Providers**

• **NetApp Trident**
• **Dell EMC PowerScale / Isilon**
• **HPE 3PAR / Nimble**
• **IBM Spectrum Scale (GPFS)**
• **Hitachi Vantara**

### **Distributed Storage Providers**

• **Ceph RBD / CephFS**
• **Rook (Ceph operator)**
• **MinIO** (S3-compatible)
• **Longhorn** (popular in Rancher clusters)
• **OpenEBS**
• **GlusterFS**
• **Portworx (Pure Storage)**
• **StorageOS / Ondat**

### **Cloud Storage Providers (Managed Storage)**
These are built-in storage services provided by cloud platforms.
##### **AWS**
• **EBS** (Elastic Block Store) – block storage
• **EFS** (Elastic File System) – shared NFS storage
• **FSx** (Lustre, NetApp ONTAP, Windows File Server)
##### **GCP**
• **GCE Persistent Disk**
• **Filestore** (NFS)
• **Local SSD**
##### **Azure**
• **Azure Managed Disks**
• **Azure Files** (SMB/NFS)
• **Azure NetApp Files**

---

# **NFS-Based Storage Providers**

• Standard **NFS Server** (self-hosted)
• **NFS CSI Driver**
Used for shared read-write workloads.
Allows multiple Pods across nodes to share data
Widely used for shared files in production

---

# **Local & Host-Based Storage Providers**

### **Local volumes (Local PV)**

• Uses node's local SSD/NVMe
• High performance
• Not replicated

### **HostPath**

• Uses host's filesystem directory
* Not suitable for multi-node clusters
• Only for dev/test (not production)

---

# **Object Storage Providers (via S3 API)**

Used mostly for backups, logs, ML models, and static content.

• AWS S3
• MinIO
• Google Cloud Storage
• Azure Blob Storage
• Ceph Object Gateway (RGW)

(Used outside the pod filesystem; accessed via SDK or s3fs.)

---

# **SAN / Block Storage Providers**

• Fibre Channel (FC)
• iSCSI
  * Uses iSCSI (SCSI over IP) block storage.
  * Provides dedicated remote block storage.
  * Requires specialized iSCSI setup and configuration.
• NVMe-oF
• Pure Storage
• NetApp ONTAP
• Dell EMC PowerStore

Used for high-performance databases.

---

# **Quick Summary Table**

| Provider Type  | Examples                         | Use Case              |
| -------------- | -------------------------------- | --------------------- |
| Cloud Storage  | EBS, GCP PD, Azure Disk          | Cloud clusters        |
| CSI Providers  | Ceph, NetApp, Longhorn, Portworx | Enterprise production |
| NFS            | Filestore, EFS, NFS server       | Shared RW workloads   |
| Local          | Local PV, HostPath               | High IOPS, testing    |
| Object Storage | S3, MinIO, GCS                   | Backups, media, ML    |

