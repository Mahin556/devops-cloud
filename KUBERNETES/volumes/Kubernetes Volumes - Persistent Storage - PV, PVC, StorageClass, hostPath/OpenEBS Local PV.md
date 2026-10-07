### Dynamic Provisioning for Local PVs (CSI)
* OpenEBS Local PV is a CSI (Container Storage Interface) driver that creates a Persistent Volume on node-local storage automatically/dynamically.
* `hostPath` and local PV require manual creation of PVs.
* But OpenEBS Local PV = automatic local PV creation.

* Install OpenEBS
  * CSI driver
  * Node agent daemonset
  * Provisioner
    ```bash
    kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
    ```
---

#### LocalPV Hostpath (Beginner Friendly, Fastest)
* You create a StorageClass
    ```yaml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: openebs-local
    provisioner: openebs.io/local
    volumeBindingMode: WaitForFirstConsumer
    ```

* Create PVC
    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: demo-pvc
    spec:
      storageClassName: openebs-local
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
    ```
  * OpenEBS will:
    * Detect the node where Pod schedules
    * Create a directory or device path
    * Create a PV dynamically
    * Attach automatically
    * Bind PVC
    * Mount PV into Pod

* Create Pod
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo-pod
    spec:
      containers:
      - name: demo
        image: nginx
        volumeMounts:
        - mountPath: /data
          name: demo-vol
      volumes:
      - name: demo-vol
        persistentVolumeClaim:
          claimName: demo-pvc
    ```

* Default hostpath root:
```bash
/var/openebs/local/

/var/openebs/local/pvc-3f34f2d6-45f9-11ec-bf3f-42010a800005/
```

---

#### LocalPV Device (NVMe/SSD/HDD Disk — Best for Databases)

* Uses real disk → maximum speed
* Perfect for MySQL, PostgreSQL, MongoDB
* OpenEBS handles formatting + mounting

```bash
lsblk   # find free disk e.g. /dev/nvme0n1
```
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-local-device
provisioner: openebs.io/local
parameters:
  storageType: device
volumeBindingMode: WaitForFirstConsumer
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-device-pvc
spec:
  storageClassName: openebs-local-device
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: device-test
spec:
  containers:
  - name: db
    image: mysql:8
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: test123
    volumeMounts:
    - mountPath: /var/lib/mysql
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: local-device-pvc
```


---

#### LocalPV ZFS (Snapshots, Compression, Dedupe)

* Check if your system supports ZFS
    * ZFS works best on:
      * Ubuntu
      * Debian
      * CentOS 8 / RHEL clones
      * Any Linux with DKMS support

```bash
uname -r
```

```bash
#For Ubuntu / Debian
sudo apt update
sudo apt install -y zfsutils-linux

#For CentOS / RHEL / Rocky / Alma
#First enable ZFS repository:
sudo yum install -y epel-release
sudo yum install -y https://zfsonlinux.org/epel/zfs-release.el7_9.noarch.rpm

#Install:
sudo yum install -y zfs
sudo modprobe zfs

zfs version
```
```bash
#Identify free disks for ZFS pool
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

sda   100G   disk
sdb   200G   disk   <-- free disk for ZFS
nvme0n1 500G disk  <-- another free disk

#Pick ONLY unused and empty disks.
#Example we will use /dev/sdb.
```

* Create a ZFS Pool (zpool)
```bash
sudo zpool create zpool1 /dev/sdb

zpool status
  pool: zpool1
  state: ONLINE
```

* Create a ZFS Dataset inside the Pool
```bash
sudo zfs create zpool1/data01

zfs list
  NAME             USED  AVAIL  REFER  MOUNTPOINT
  zpool1           300K   190G     0B  /zpool1
  zpool1/data01    24K    190G   24K   /zpool1/data01

```

* Enable Useful Features (Optional but Recommended)
    ```bash
    sudo zfs set compression=lz4 zpool1 #Enable compression:
    sudo zfs set snapdir=visible zpool1 #Enable auto snapshot:
    sudo zfs set dedup=on zpool1 #Enable deduplication (only if you have >16GB RAM):
    ```

* (Required) Install OpenEBS ZFS Driver
```bash
kubectl apply -f https://openebs.github.io/charts/zfs-operator.yaml

kubectl get pods -n openebs
  openebs-zfs-controller
  openebs-zfs-node
```

* Example StorageClass for ZFS LocalPV
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-zfspv
provisioner: zfs.csi.openebs.io
parameters:
  poolname: "zpool1"
  fstype: "zfs"
volumeBindingMode: WaitForFirstConsumer
```
    * Uses the zpool1 you created
    * Dynamic provisioning
    * Supports snapshots, clones, compression

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: zfs-test-pvc
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: openebs-zfspv
  resources:
    requests:
      storage: 5Gi
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: zfs-test
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: zfs-test-pvc
```

---

### LocalPV LVM (Thin/Thick Provisioning + Resize Support)

```bash
sudo apt update
sudo apt install -y lvm2 #Ubuntu / Debian

sudo yum install -y lvm2 #CentOS / RHEL / Rocky / Alma

lvm version #Verify LVM install
```
```bash
lsblk -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT

sda   100G   disk  
sdb   200G   disk   <-- FREE, use for LVM VG
sdc   200G   disk   <-- optional second disk
```
```bash
sudo wipefs -a /dev/sdb #Wipe disk (Only if disk is new/empty)
```

```bash
sudo pvcreate /dev/sdb
sudo pvs

sudo vgcreate vg1 /dev/sdb
sudo vgs
sudo vgdisplay vg1
```
* Install OpenEBS LVM LocalPV Plugin
```bash
kubectl apply -f https://openebs.github.io/charts/openebs-operator-lvm.yaml

kubectl get pods -n openebs
  openebs-lvm-node
  openebs-lvm-controller
```
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-lvm
provisioner: lvm.csi.openebs.io
parameters:
  volgroup: "vg1"
  provisioningType: "thin"      # thick also supported
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: lvm-pvc
spec:
  storageClassName: openebs-lvm
  accessModes: [ "ReadWriteOnce" ]
  resources:
    requests:
      storage: 10Gi
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lvm-test
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep infinity"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: lvm-pvc
```

---
