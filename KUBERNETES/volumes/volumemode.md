* HOW the volume is exposed inside the Pod.

| Mode           | Meaning                          |
| -------------- | -------------------------------- |
| **Filesystem** | Volume is mounted as a directory |
| **Block**      | Raw block device is attached     |

```bash
VOLUMEMODE IN KUBERNETES (PV / PVC)

volumeMode defines HOW storage is presented inside a Pod.
It is NOT about access (RWO/RWX) — it is about folder vs raw disk.

────────────────────────────────────────

1️⃣ Filesystem (Default)

Meaning:
• Kubernetes formats the volume with a filesystem
• Mounted as a normal directory inside the container

Pod sees:
  /data/file.txt

Used for:
• App data
• Logs
• Web content
• Most databases

Example PV + PVC + Pod:

PV
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce

PVC
spec:
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi

Pod
volumeMounts:
- name: storage
  mountPath: /data

Result: Container reads/writes files normally.

────────────────────────────────────────

2️⃣ Block (Raw Device)

Meaning:
• Volume is NOT formatted
• Attached as raw disk device

Pod sees:
  /dev/xvda

Used for:
• Databases managing their own filesystem
• High-performance storage
• Storage systems (Ceph, etc.)

Example PV + PVC + Pod:

PV
spec:
  capacity:
    storage: 10Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce

PVC
spec:
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi

Pod
volumeDevices:
- name: disk
  devicePath: /dev/xvda

Result: App interacts directly with disk device.

────────────────────────────────────────

IMPORTANT RULE
PV and PVC must have SAME volumeMode or binding fails.

────────────────────────────────────────

MEMORY LINE
Filesystem = Folder
Block = Raw disk device
```
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: block-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /dev/loop10   # Example block device on node
    type: BlockDevice
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: block-pvc
spec:
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 1Gi
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: block-pod
spec:
  containers:
  - name: app
    image: ubuntu
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
    volumeDevices:
      - name: block-storage
        devicePath: /dev/xvda

  volumes:
    - name: block-storage
      persistentVolumeClaim:
        claimName: block-pvc
```
```bash
kubectl exec -it block-pod -- lsblk
kubectl exec -it block-pod -- df -h
```