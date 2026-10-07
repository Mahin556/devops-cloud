* Applications in Kubernetes need **persistent storage** to save data.
* Storage usually exists **outside the cluster** (like NFS server).
* Without StorageClass:
  * Every time a team needs storage:
    * They must contact the **storage team**
    * Storage team manually:
      * Creates a directory
      * Configures NFS export
      * Creates a Persistent Volume (PV)
  * This is **slow, manual, and repetitive**.

* Problem without StorageClass:
  * Manual provisioning of PVs
  * High dependency on storage team
  * Not scalable for many apps
  * Dev/Test/Prod teams keep waiting

* StorageClass solves this by enabling **Dynamic Provisioning**
* What StorageClass does:
  * Acts like a **template** for storage
  * Connected to real storage (like NFS base directory)
  * Automatically creates PVs when needed

* Flow with StorageClass:
  1. Storage team sets up **one base storage**
     Example: `/k8s-data` on NFS
  2. Kubernetes admin creates a **StorageClass** pointing to that NFS location
  3. Developer creates only a **PVC** (not PV)
  4. Kubernetes automatically:
     * Creates a PV
     * Allocates space from base storage
     * Binds PV to PVC

* So now:

  | Without StorageClass           | With StorageClass           |
  | ------------------------------ | --------------------------- |
  | Manual PV creation             | Automatic PV creation       |
  | Storage team needed every time | No storage team involvement |
  | Slow                           | Fast                        |
  | Static provisioning            | Dynamic provisioning        |

* StorageClass = **automatic storage factory**
  PVC = **request form**
  PV = **actual storage created** inside the nfs share(`/k8s-data`)

* Multiple teams (Dev/Test/Prod) can:
  * Just create PVC
  * Get isolated storage automatically

* NFS server:
  * Not part of cluster
  * Just provides shared storage
  * StorageClass connects Kubernetes to it

* Analogy (Linux background):
  > StorageClass works like **automatic LVM creation**
  > You request space → system creates volume automatically

---

```bash
#Server
apt update #ubuntu
apt install nfs-kernel-server -y

mkdir --mode=777 /k8s-data
chown nobody /k8s-data

echo "/k8s-data *(rw,sync,no_subtree_check)" >> /etc/exports
exportfs -a
exportfs -r
exportfs -v

systemctl restart nfs-kernel-server #ubuntu
systemctl status nfs-kernel-server

showmount -e localhost
showmount -e <nfs_server_ip>

#client(all worker)
apt update #ubuntu
apt install nfs-common -y && showmount -e <nfs_server_ip> #need to installed on all worker and control plane nodes
apt install nfs-common -y && showmount -e 
```
```bash
<<<<<<< HEAD
=======
████████████  NFS SERVER SETUP (RHEL / CENTOS / ROCKY / ALMA)  ████████████

1️⃣ Install NFS packages
dnf install nfs-utils -y

2️⃣ Create shared folder
mkdir -p /k8s-data
chmod 777 /k8s-data
chown -R nobody:nobody /k8s-data

3️⃣ Configure export
echo "/k8s-data *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports

4️⃣ Apply export
exportfs -rav

5️⃣ Start NFS services
systemctl enable --now rpcbind
systemctl enable --now nfs-server
systemctl enable --now nfs-mountd
systemctl enable --now nfs-idmapd

6️⃣ Open firewall
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload

7️⃣ Verify
showmount -e localhost
```
```bash
>>>>>>> 8b31efea7da9bad8728e188cecbbc41bc17a1137
kubectl get pv
kubectl get pvc
kubectl get pods

helm version
# Add nfs provisioner
helm repo add nfs-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo list

kubectl create namespace storage-nfs

helm install nfs-provisioner nfs-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=10.0.0.99 \
  --set nfs.path=/k8s-data \
  --set storageClass.name=nfs-client \
  --set storageClass.onDelete=true \
  --namespace storage-nfs

kubectl get storageclass
kubectl describe storageclass nfs-client

cat <<EOF | tee app1-pvc.yaml | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sample-nfs-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF


kubectl get pv,pvc

cat <<EOF | tee app1-deploy.yaml | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nfs-nginx-svc
spec:
  selector:
    app: sc-nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1 
kind: Deployment
metadata:
  labels:
    app: sc-nginx
  name: nfs-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sc-nginx
  template:
    metadata:
      labels:
        app: sc-nginx
    spec:
      volumes:
      - name: nfs-test
        persistentVolumeClaim:
          claimName: sample-nfs-pvc
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
        - name: nfs-test # template.spec.volumes[].name
          mountPath: /usr/share/nginx/html # mount inside of container
          #readOnly: true # if enforcing read-only on volume
        ports:
        - containerPort: 80
EOF

kubectl get pods
kubectl get svc
kubectl describe pod <pod-name>

kubectl exec -it <pod-name> -- df -h

cd /k8s-data/<pv_dir>
echo "<h1>NFS storage class</h1>" > index.html
curl http://<service-ip>

cat <<EOF | tee app2-pvc.yaml | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: apache-nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pv,pvc

cat << EOF | tee app2-deploy.yaml | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: apache-svc
spec:
  selector:
    app: apache
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1 
kind: Deployment
metadata:
  labels:
    app: apache
  name: webserver
spec:
  replicas: 2
  selector:
    matchLabels:
      app: apache
  template:
    metadata:
      labels:
        app: apache
    spec:
      volumes:
      - name: web-root
        persistentVolumeClaim:
          claimName: apache-nfs-pvc
      containers:
      - image: lovelearnlinux/webserver:v1
        name: apache
        volumeMounts:
        - name: web-root # template.spec.volumes[].name
          mountPath: /var/www/html # mount inside of container
          #readOnly: true # if enforcing read-only on volume
        ports:
        - containerPort: 80
EOF

kubectl get pods
kubectl get svc
kubectl describe pod <pod-name>

cd /k8s-data/<pv_dir>
echo "This is Apache app from NFS" > index.html
curl http://<apache-service-ip>
```

---

```bash
cat << EOF | tee pv.yaml | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs
spec:
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  nfs:
    server: 192.168.1.7
    path: /srv/nfs
EOF

cat << EOF | tee pvc.yaml | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  resources:
    requests:
      storage: 100Mi
EOF

cat << EOF | tee deploy.yaml | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nfs-web-svc
spec:
  selector:
    app: nfs-web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-web
  template:
    metadata:
      labels:
        app: nfs-web
    spec:
      containers:
      - name: nfs-web
        image: nginx
        ports:
        - name: web
          containerPort: 80
        volumeMounts:
        - name: nfs
          mountPath: /usr/share/nginx/html
      volumes:
      - name: nfs
        persistentVolumeClaim:
          claimName: nfs
EOF

cd /srv/nfs
echo "<h1>NFS storage class</h1>" > index.html
kubectl exec -it nfs-web-xxxx -- /bin/bash
cd /usr/share/nginx/html
ls
touch test
```

---

```bash
cat << EOF | tee rbac.yaml | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

cat << EOF | tee sc1.yaml | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client1
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "false"
EOF

cat << EOF | tee sc2.yaml | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client2
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "true"
EOF


kubectl patch storageclass nfs-client1 \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

cat << EOF | tee deploy.yaml | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 10.3.243.101
            - name: NFS_PATH
              value: /ifs/kubernetes
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.3.243.101
            path: /ifs/kubernetes
EOF

cat << EOF | tee pvc1.yaml | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim1
spec:
  storageClassName: nfs-client1
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
EOF

cat << EOF | tee pvc2.yaml | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim2
spec:
  storageClassName: nfs-client2
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
EOF

kubectl get pv,pvc
\ls /k8s-data/
default-test-claim-pvc-288c8b03-0358-435e-a668-2111780742c8  index.html

cat << EOF | tee pod1.yaml | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: test-pod1
spec:
  containers:
  - name: test-pod1
    image: busybox:stable
    command:
      - "/bin/sh"
    args:
      - "-c"
      - "touch /mnt/SUCCESS && exit 0 || exit 1"
    volumeMounts:
      - name: nfs-pvc
        mountPath: "/mnt"
  restartPolicy: "Never"
  volumes:
    - name: nfs-pvc
      persistentVolumeClaim:
        claimName: test-claim1
EOF

cat << EOF | tee pod2.yaml | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: test-pod2
spec:
  containers:
  - name: test-pod2
    image: busybox:stable
    command:
      - "/bin/sh"
    args:
      - "-c"
      - "touch /mnt/SUCCESS && exit 0 || exit 1"
    volumeMounts:
      - name: nfs-pvc
        mountPath: "/mnt"
  restartPolicy: "Never"
  volumes:
    - name: nfs-pvc
      persistentVolumeClaim:
        claimName: test-claim2
EOF

```

