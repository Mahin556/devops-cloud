* A **ConfigMap** is a Kubernetes API object used to store **non-confidential configuration data** in key-value pairs.

* ConfigMaps allow you to keep config values separate(decouple) from your code and container images.

* Externalize environment-specific settings, such as a database hostname, URLs, settings or IP address, without modifying the container image. 

* Stored in plane-text in etcd if anyone gain access to etcd they see info in plane text.

* Make application portable and easy to manage accross different environment.

* Often used alongside **Secrets** (which are for sensitive data).

* `Non-sensitive` key-value config data. 

* Values can be `strings` or `Base64-encoded binary data`.

* Injected as `Environment Variable` or `ConfigMap`.

* Application can take value from the Environment variable and from the file.

* Prevent image rebuilding.

* Store relatively small amounts of simple data.

* The total size of a ConfigMap object must be less than `1 MiB`. To store more data we should split your configuration into multiple `ConfigMaps` or consider using a `separate database` or `key-value store`.

* Application must be designed to use the configuration from the environment variable and file.

```bash
# From literal key-value pairs
kubectl create configmap mysql-config \
  --from-literal=MYSQL_HOST=mysql.dev.local \
  --from-literal=MYSQL_PORT=3306 \
  --from-literal=MYSQL_DATABASE=mydb

# From a single file
kubectl create configmap mysql-config --from-file=config.txt
# Key --> config.txt
# Value --> file content

# From multiple files
kubectl create configmap mysql-config \
  --from-file=db.conf \
  --from-file=app.conf

# From a directory
kubectl create configmap mysql-config --from-file=./config-dir/

# From specific key=filename mapping
kubectl create configmap mysql-config --from-file=custom_key=db.conf
# Key name becomes custom_key instead of filename

# From env file (.env format)
kubectl create configmap mysql-config --from-env-file=.env

# Combine multiple sources
kubectl create configmap mysql-config \
  --from-literal=ENV=dev \
  --from-file=config.txt \
  --from-env-file=.env

# Dry-run (generate YAML without creating)
kubectl create configmap mysql-config \
  --from-literal=MYSQL_HOST=mysql.dev.local \
  --dry-run=client -o yaml

# Create + save YAML to file
kubectl create configmap mysql-config \
  --from-literal=MYSQL_HOST=mysql.dev.local \
  --dry-run=client -o yaml > configmap.yaml

# Create in specific namespace
kubectl create configmap mysql-config \
  --from-literal=MYSQL_HOST=mysql.dev.local \
  -n dev

# Update (since create won’t overwrite)
kubectl create configmap mysql-config \
  --from-literal=MYSQL_HOST=newhost \
  --dry-run=client -o yaml | kubectl apply -f -
```
```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  MYSQL_HOST: "mysql.dev.local"
  MYSQL_PORT: "3306"
  MYSQL_DATABASE: "mydb"
EOF

kubectl apply -f -<<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  db.conf: | 
    MYSQL_HOST: "mysql.dev.local"
    MYSQL_PORT: "3306"
    MYSQL_DATABASE: "mydb"
EOF
```
---

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
stringData:
  APP_ENV: "dev"
  DEBUG: "true"
```
* Kubernetes converts it into `data` internally

---

File-style ConfigMap (multi-line config)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
      listen 80;
      location / {
        return 200 "Hello";
      }
    }
```

---

Binary data (rare)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: binary-config
binaryData:
  file.bin: "aGVsbG8="   # base64 encoded
```

---

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
data:
  app_name: "demo-app"
  environment: "production"
binaryData:
  file_template: RGVtbwo=    # Base64 for "Demo\n"
```

---

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      volumes:
        - name: secret-volume
          secret:
            secretName: backend-secret
      containers:
        - name: backend-container
          image: hashicorp/http-echo
          args:
            - "-text=Hello from Backend"
          volumeMounts:
          - name: secret-volume
            mountPath: /etc/secrets
            readOnly: true
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 9090
      targetPort: 5678
  selector:
    app: backend
```

---

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-cm
data:
  APP: "frontend"
  ENVIRONMENT: "production"
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Welcome</title>
    </head>
    <body>
        <h1>This page is served by nginx.</h1>
        <h2>The dark side of the moon!!</h2>
        <h3>The dark side of the moon-2!!</h3>
    </body>
    </html>
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      volumes:
        - name: frontend-cm
          configMap:
            name: frontend-cm
      containers:
        - name: frontend-container
          image: hashicorp/http-echo
          args:
            - "-text=Hello from Frontend"
          volumeMounts:
          - name: frontend-cm
            mountPath: /etc/cm
            readOnly: true
```

---

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend-container
          image: nginx
          env:
            - name: APP
              valueFrom:
                configMapKeyRef:
                  name: frontend-cm
                  key: APP
            - name: ENVIRONMENT
              valueFrom:
                configMapKeyRef:
                  name: frontend-cm
                  key: ENVIRONMENT
```

---

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend-container
          image: nginx
          env:
            - name: APP
              valueFrom:
                configMapKeyRef:
                  name: frontend-cm
                  key: APP
            - name: ENVIRONMENT
              valueFrom:
                configMapKeyRef:
                  name: frontend-cm
                  key: ENVIRONMENT
          volumeMounts:
            - name: html-volume
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
      volumes:
        - name: html-volume
          configMap:
            name: frontend-cm
```

---

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend-container
          image: nginx
          env:
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: frontend-secret
                  key: DB_USER
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: frontend-secret
                  key: DB_PASSWORD
```

---

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      volumes:
        - name: secret-volume
          secret:
            secretName: frontend-secret
      containers:
        - name: frontend-container
          image: nginx
          env:
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: frontend-secret
                  key: DB_USER
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: frontend-secret
                  key: DB_PASSWORD
          volumeMounts:
          - name: secret-volume
            mountPath: /etc/secrets
            readOnly: true
```

---

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: frontend-secret
type: Opaque
data:
  DB_USER: ZnJvbnRlbmR1c2Vy
  DB_PASSWORD: ZnJvbnRlbmRwYXNz
```

---

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  MYSQL_HOST: "mysql.dev.local"
  MYSQL_PORT: "3306"
  MYSQL_DATABASE: "mydb"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-app
  template:
    metadata:
      labels:
        app: mysql-app
    spec:
      containers:
        - name: app-container
          image: nginx   # replace with your app image
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: mysql-config
```

---

```bash
kubectl create configmap my-config \
  --from-file=prod-app.conf=prod/app.conf \
  --from-file=dev-app.conf=dev/app.conf
```

---

```bash
cat << EOF > nginx.conf
 # The identifier Backend is internal to nginx, and used to name this specific upstream
upstream Backend {
    # hello is the internal DNS name used by the backend Service inside Kubernetes
    server dsp;
}

server {
    listen 80;

    location / {
        # The following statement will proxy traffic to the upstream named Backend
        proxy_pass http://Backend;
    }
} 
EOF
```
```bash
kubectl create namespace sandbox
```
```bash
kubectl create configmap -n sandbox nginx-conf --from-file=./nginx.conf
```
```bash
kubectl describe cm nginx-conf -n sandbox

# Name:         nginx-conf
# Namespace:    sandbox
# Labels:       <none>
# Annotations:  <none>

# Data
# ====
# nginx.conf:
# ----
#  # The identifier Backend is internal to nginx, and used to name this specific upstream
# upstream Backend {
#     # hello is the internal DNS name used by the backend Service inside Kubernetes
#     server dsp;
# }

# server {
#     listen 80;

#     location / {
#         # The following statement will proxy traffic to the upstream named Backend
#         proxy_pass http://Backend;
#     }
# } 



# BinaryData
# ====

# Events:  <none>
```
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: sandbox
spec:
  selector:
    matchLabels:
      run: nginx
      app: dsp
      tier: frontend
  replicas: 2
  template:
    metadata:
      labels:
        run: nginx
        app: dsp
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx
        env:
        # Define the environment variable
        - name: nginx-conf
          valueFrom:
            configMapKeyRef:
              # The ConfigMap containing the value you want to assign to SPECIAL_LEVEL_KEY
              name: nginx-conf
              # Specify the key associated with the value
              key: nginx.conf
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
        ports:
          - containerPort: 80 
        volumeMounts:
          - mountPath: /etc/nginx/demo
            name: nginx-conf
      volumes:
      - name: nginx-conf
        configMap: 
          name: nginx-conf
          items:
            - key: nginx.conf
              path: nginx.conf
EOF
```
```bash
kubectl config set-context --namespace sandbox --current
```

* When a ConfigMap is mounted as a **volume**, any updates to the ConfigMap are automatically propagated to the files inside the Pod.
* Unlike environment variables or command-line arguments, Pods **do not need to be restarted** to see the new values.

```bash
# Update the nginx.conf and recreate the config map nginx-conf
# ConfigMap updated → API Server → kubelet detects → new version created → symlink switched → container sees updated data (app reload needed).
# ConfigMap files are stored on the node at:
/var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~configmap/<configmap-name>/

#Here is the actual directory structure of a ConfigMap on the node (inside kubelet storage):
/var/lib/kubelet/pods/<pod-uid>/
└── volumes/
    └── kubernetes.io~configmap/
        └── <configmap-name>/
            ├── ..2026_04_24_03_39_14.xxxxx/   # actual data (versioned dir)
            │   ├── nginx.conf
            │   ├── key2
            │   └── key3
            │
            ├── ..data -> ..2026_04_24_03_39_14.xxxxx   # symlink to current version
            │
            ├── nginx.conf -> ..data/nginx.conf         # file symlink
            ├── key2 -> ..data/key2
            └── key3 -> ..data/key3
```

---

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
data:
  database_host: "192.168.0.1"
  debug_mode: "true"
  log_level: "verbose"
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
spec:
  containers:
    - name: app
      image: busybox:latest
      command: ["sh", "-c", "echo 'Files from ConfigMap:' && ls -l /etc/app-config && echo && cat /etc/app-config/log_level && sleep 3600"]
      volumeMounts:
        - name: config
          mountPath: "/etc/app-config"
          readOnly: true #Prevents modification from inside the container
  volumes:
    - name: config
      configMap:
        name: demo-config
```

---