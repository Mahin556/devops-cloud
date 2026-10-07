* Local PV = High-performance node-local storage managed by Kubernetes as real persistent storage.
* A Local PersistentVolume (Local PV) uses a physical disk or directory on a specific node as a Kubernetes storage volume.
* Examples of what can back a Local PV:
    * `/dev/nvme0n1` (NVMe SSD)
    * `/mnt/ssd-disk1`
    * `/var/lib/data`
    * `/mnt/hdd1`
    * Dedicated partitions created via lsblk
* Local PV looks like a normal PV to the user, but the storage is local to a specific node, not remote storage like EBS or NFS.
- Mounts a physical disk attached to a node.
- Can be implemented as either in-tree or CSI-based, depending on the setup.
- Useful for tightly coupled environments like on-premises clusters.
- Works well with **PersistentVolume** and supports **node affinity** for proper pod scheduling.

* **Why?**
    * Databases (PostgreSQL, MongoDB, MySQL, MariaDB)
    * Caching systems (Redis, Aerospike)
    * Message queues (Kafka, Pulsar)
    * ElasticSearch
    * Cassandra
    * ML/AI workloads
        * TensorFlow
        * PyTorch
    * Analytics jobs (Spark, Presto)
    * On-prem clusters where nodes have:
        * SSDs
        * NVMEs
        * RAID arrays
* **Local PV provides:**
    * High IOPS
    * Low latency
    * Direct-disk performance
    * Guaranteed node affinity

* **Local PV Requires Manual Volume Discovery**
    * The disk
    * The mountpoint
    * The directory
    * Permissions

* **Pros & Cons (Practical)**
  * **Pros**
    * Extremely fast (NVMe speed)
    * Perfect for DBs
    * Pod automatically placed on correct node
    * Supports PVC
    * Works with dynamic provisioning (CSI LocalPV)
    * High reliability
  * **Cons**
    * Not suitable if Pod must move to other nodes
    * Node failure = Volume unavailable
    * Manual provisioning unless using CSI
    * Only RWO access mode (no ReadWriteMany)

---
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-ssd
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  persistentVolumeReclaimPolicy: Delete
  local:
    path: /dev/vda1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
            - node01
EOF
```
* /dev/vda1 must exist on worker-node-1
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 1Gi
EOF
```
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app-using-localpv
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - mountPath: /data
      name: local-volume
  volumes:
  - name: local-volume
    persistentVolumeClaim:
      claimName: local-pvc
EOF
```
