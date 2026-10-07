### ReadWriteOnce (RWO)
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-rwo-local
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /data/rwo
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - controlplane
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-rwo
spec:
  storageClassName: ""   # 🔥 THIS LINE IS KEY
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod1
spec:
  nodeSelector:
    kubernetes.io/hostname: controlplane
  containers:
  - image: busybox
    name: c1
    command: ["sh","-c","sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: vol
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: pvc-rwo
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod2
spec:
  nodeSelector:
    kubernetes.io/hostname: node01
  containers:
  - image: busybox
    name: c1
    command: ["sh","-c","sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: vol
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: pvc-rwo
EOF
```

---

### ReadWriteMany (RWX)
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nfs-server
  labels:
    app: nfs-server
spec:
  containers:
  - name: nfs
    image: itsthenetwork/nfs-server-alpine:latest
    securityContext:
      privileged: true
    env:
    - name: SHARED_DIRECTORY
      value: /exports
    volumeMounts:
    - mountPath: /exports
      name: data
  volumes:
  - name: data
    emptyDir: {}
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nfs-service
spec:
  selector:
    app: nfs-server
  ports:
  - port: 2049
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-rwx
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  nfs:
    server: <CLUSTER-IP>
    path: /
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-rwx
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-a
spec:
  nodeName: controlplane
  containers:
  - name: c1
    image: busybox
    command: ["sh","-c","sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: vol
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: pvc-rwx
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-b
spec:
  nodeName: node01
  containers:
  - name: c1
    image: busybox
    command: ["sh","-c","sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: vol
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: pvc-rwx
EOF

kubectl exec pod-a -- sh -c "echo RWX-WORKS > /data/test.txt"
kubectl exec pod-b -- cat /data/test.txt
```