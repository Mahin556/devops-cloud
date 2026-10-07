```yaml
kubectl apply -f -<<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
        - image: mongo
          name: mongo
          args: ["--dbpath", "/data/db"]
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              value: "admin"
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: "password"
EOF
```
```yaml
kubectl apply -f -<<EOF
apiVersion: v1
kind: Service
metadata:
  name: mongo-svc
spec:
  ports:
    - port: 27017
      protocol: TCP
      targetPort: 27017
      nodePort: 32000
  selector:
    app: mongo
  type: NodePort
EOF
```
```bash
> kubectl exec -it mongo-587ffcc649-bgr5x -- mongosh

> kubectl exec -it mongo-587ffcc649-bgr5x -- mongosh --username YOUR_USERNAME --password YOUR_PASSWORD --authenticationDatabase admin

> kubectl exec -it mongo-587ffcc649-bgr5x -- mongosh --username admin --password password --authenticationDatabase admin

> kubectl exec -it <pod-name> -- mongosh -u <user> -p <pass> --authenticationDatabase <auth-db> --eval "<mongo command>"

> kubectl exec -it mongo-587ffcc649-bgr5x -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval "show dbs"

> kubectl exec -it mongo-587ffcc649-bgr5x -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval "use mydb; show collections"

> kubectl exec -it mongo-587ffcc649-bgr5x -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval 'db.users.insertOne({name:"Mahin", role:"DevOps"})'

> kubectl exec -it mongo-587ffcc649-bgr5x -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval 'db.users.find().pretty()'

> kubectl exec -it mongo-587ffcc649-bgr5x -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval 'db.mydb.insertOne({name:"Mahin", role:"DevOps"})'

> kubectl exec -it mongo-587ffcc649-bgr5x -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval 'db.mydb.find().pretty()'

> kubectl exec -it mongo-587ffcc649-bgr5x -- ps -ef

> kubectl exec -it mongo-587ffcc649-bgr5x -- kill 1

> kubectl get pod -w

> kubectl exec -it mongo-587ffcc649-bgr5x -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval "show dbs"
```

---
---

* Data persiste accross container restart but not pod recreation/restart.
* `emptyDir`  allow data persiste accross container restarts and data share between all containers in a pod.
* `emptyDir` not provide persistency across pod recreation or sharing data between pods.

```yaml
kubectl apply -f -<<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
        - image: mongo
          name: mongo
          args: ["--dbpath", "/data/db"]
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              value: "admin"
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: "password"
          volumeMounts:
            - mountPath: /data/db
              name: mongo-volume
      volumes:
        - name: mongo-volume
          emptyDir: {}
EOF
```
```yaml
kubectl apply -f -<<EOF
apiVersion: v1
kind: Service
metadata:
  name: mongo-svc
spec:
  ports:
    - port: 27017
      protocol: TCP
      targetPort: 27017
      nodePort: 32000
  selector:
    app: mongo
  type: NodePort
EOF
```
```bash
> kubectl get pods mongo-86df59cf77-cv8mt -o jsonpath='{.metadata.uid}'
a0db116f-19c5-4a3b-a24e-c4ea2355f3c7

> kubectl get pods -owide
NAME                     READY   STATUS    RESTARTS   AGE    IP              NODE               
  NOMINATED NODE   READINESS GATES
mongo-86df59cf77-cv8mt   1/1     Running   0          117s   10.244.244.68   worker02.server.vm   <none>           <none>

> ssh worker02.server.vm

> ls /var/lib/kubelet/pods/a0db116f-19c5-4a3b-a24e-c4ea2355f3c7

> ls /var/lib/kubelet/pods/a0db116f-19c5-4a3b-a24e-c4ea2355f3c7/volumes/
kubernetes.io~empty-dir  kubernetes.io~projected

> kubectl delete pods mongo-86df59cf77-cv8mt 

> ssh worker02.server.vm

> ls /var/lib/kubelet/pods/a0db116f-19c5-4a3b-a24e-c4ea2355f3c7
ls: cannot access '/var/lib/kubelet/pods/a0db116f-19c5-4a3b-a24e-c4ea2355f3c7': No such file or directory

> kubectl get pods -owide
NAME                     READY   STATUS    RESTARTS   AGE    IP              NODE               
  NOMINATED NODE   READINESS GATES
mongo-86df59cf77-qz2sd   1/1     Running   0          117s   10.244.244.68   worker02.server.vm   <none>           <none>
```

---
---

```yaml
kubectl apply -f -<<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      nodeName: worker02.server.vm
      containers:
        - image: mongo
          name: mongo
          args: ["--dbpath", "/data/db"]
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              value: "admin"
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: "password"
          volumeMounts:
            - mountPath: /data/db
              name: mongo-volume
      volumes:
        - name: mongo-volume
          hostPath:
            path: /data
EOF
```
```yaml
kubectl apply -f -<<EOF
apiVersion: v1
kind: Service
metadata:
  name: mongo-svc
spec:
  ports:
    - port: 27017
      protocol: TCP
      targetPort: 27017
      nodePort: 32000
  selector:
    app: mongo
  type: NodePort
EOF
```
```bash
> kubectl exec -it mongo-85cbd74ddb-4nmkv -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval "show dbs"

> kubectl exec -it mongo-6d4cc69d76-d7gd5 -- \
mongosh -u admin -p password --authenticationDatabase admin \
--eval 'use mydb; db.test.insertOne({name:"Mahin", role:"DevOps"})'


> ssh root@worker02
> ls /data/
collection-2720d155-fcee-4323-9b0f-a78016f83eb3.wt
collection-56e9cf4c-c9c0-4724-bb55-0fdabc62c1dd.wt
collection-b344a9a5-b212-4416-960f-7f337dad7675.wt
collection-b789a98e-fc0d-4545-800b-24ee704b97ec.wt
diagnostic.data
index-19914908-5607-4d58-b811-2e1cd1649bf6.wt
index-280c5ca0-9647-4161-89b6-2fc89fdf6702.wt
index-798b8837-a410-4df6-aabf-d1a271a8d495.wt
index-79cb481e-1191-469e-b819-e7e6717ecb53.wt
index-81389b55-2673-4c98-ad86-db041a2554a3.wt
index-8f68369c-dcca-46ac-8a66-26e37f163d9b.wt
journal
_mdb_catalog.wt
mongod.lock
sizeStorer.wt
storage.bson
_tmp
WiredTiger
WiredTigerHS.wt
WiredTiger.lock
WiredTiger.turtle
WiredTiger.wt
```
```yaml
kubectl apply -f -<<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo1
  template:
    metadata:
      labels:
        app: mongo1
    spec:
      nodeName: worker01.server.vm
      containers:
        - image: mongo
          name: mongo1
          args: ["--dbpath", "/data/db"]
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              value: "admin"
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: "password"
          volumeMounts:
            - mountPath: /data/db
              name: mongo-volume
      volumes:
        - name: mongo-volume
          hostPath:
            path: /data
EOF
```
```yaml
kubectl apply -f -<<EOF
apiVersion: v1
kind: Service
metadata:
  name: mongo-svc1
spec:
  ports:
    - port: 27017
      protocol: TCP
      targetPort: 27017
      nodePort: 32000
  selector:
    app: mongo1
  type: NodePort
EOF
```
```bash
> kubectl exec -it mongo1-5988976d57-dmpnf -- \
mongosh --username admin --password password --authenticationDatabase admin \
--eval "show dbs"
```

---

