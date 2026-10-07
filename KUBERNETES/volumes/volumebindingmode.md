```bash
# PVC BINDING BEHAVIOR IN KUBERNETES (WITH EXERCISE)

# CORE IDEA
# PVC does NOT always wait for a Pod to be created.
# Binding depends on StorageClass → volumeBindingMode.

# ────────────────────────────────────────

# MODE 1: Immediate (Default)

# WHAT HAPPENS
# • PVC binds to PV immediately after PVC creation
# • Pod is NOT required for binding
# • Scheduler is NOT involved in PV selection

# USED FOR
# • Cloud disks (EBS, GCE PD, Azure Disk)
# • Network storage
# • Storage not tied to a specific node

# FLOW
# PVC created
#    ↓
# Kubernetes finds matching PV
#    ↓
# PVC = Bound
#    ↓
# Pod can use it later

# EXERCISE

#1. Create StorageClass (Immediate mode)

cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: immediate-sc
provisioner: kubernetes.io/no-provisioner
EOF

#2. Create PV

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv1
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: immediate-sc
  hostPath:
    path: /data/immediate
    type: DirectoryOrCreate
EOF

#3. Create PVC

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
spec:
  storageClassName: immediate-sc
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

#CHECK
kubectl get pvc

#RESULT
#PVC status = Bound (even without Pod)

#────────────────────────────────────────

#MODE 2: WaitForFirstConsumer

# WHAT HAPPENS
# • PVC stays Pending after creation
# • Binding happens only after Pod is created
# • In case of alredy created PV it not bound PVC to PV until pod is created
# • Scheduler first chooses node
# • Then PV with matching nodeAffinity is selected

# USED FOR
# • Local volumes
# • Node-based storage

# FLOW
# PVC created → Pending
#    ↓
# Pod created
#    ↓
# Scheduler picks node
#    ↓
# Kubernetes selects PV on that node
#    ↓
# PVC = Bound

# EXERCISE

# 1. StorageClass
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

#2. PV (Node specific)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-sc
  local:
    path: /data/local
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node01
EOF

#3. PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  storageClassName: local-sc
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

#CHECK
kubectl get pvc

#RESULT
#PVC status = Pending (no Pod yet)

#4. Create Pod using PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep","3600"]
    volumeMounts:
    - mountPath: /data
      name: storage
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: local-pvc
EOF

#CHECK AGAIN
kubectl get pvc

# RESULT
# PVC becomes Bound after Pod scheduling
```