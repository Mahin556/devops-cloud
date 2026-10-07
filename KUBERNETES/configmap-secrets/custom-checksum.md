### **Practical: ConfigMap + Checksum (without Helm, real hands-on)**

* **Step 1: Create ConfigMap**

```bash
cat <<EOF > configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "dev"
EOF
```

```bash id="cmdpr1"
kubectl apply -f configmap.yaml
```

---

* **Step 2: Create Deployment (with manual checksum/annotation)**

```bash
cat <<EOF > deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
      annotations:
        config-version: "v1"   # 🔥 acts like checksum
    spec:
      containers:
        - name: app
          image: nginx
          envFrom:
            - configMapRef:
                name: app-config
EOF
```

```bash id="cmdpr2"
kubectl apply -f deploy.yaml
```

---

* **Step 3: Verify pod**

```bash id="cmdpr3"
kubectl get pods
```

---

* **Step 4: Update ConfigMap**

```yaml id="cmpr3"
data:
  APP_ENV: "prod"
```

```bash id="cmdpr4"
kubectl apply -f configmap.yaml
```

---

* ⚠️ **Observe**

  * Pod will NOT restart

```bash id="cmdpr5"
kubectl get pods
```

👉 same pod still running ❌

---

* **Step 5: Trigger rollout using annotation (checksum concept)**

```yaml id="cmpr4"
annotations:
  config-version: "v2"   # change value
```

```bash id="cmdpr6"
kubectl apply -f deploy.yaml
```

---

* **Step 6: Verify rollout**

```bash id="cmdpr7"
kubectl get pods
```

👉 New pod created ✅

---

* **Step 7: Check inside pod**

```bash id="cmdpr8"
kubectl exec -it <pod-name> -- env | grep APP_ENV
```

👉 Output:

```bash id="cmdpr9"
APP_ENV=prod
```

---

# 🔥 **What just happened**

* ConfigMap updated
  → pod did NOT restart

* Annotation changed
  → pod template changed
  → Deployment triggered rollout
  → new pod picked updated config

---

# 🎯 **Real DevOps understanding**

* ConfigMap change alone ❌
* Pod restart needed ✅
* checksum/annotation = trigger mechanism

---

* 🎯 **One-line**

* Change ConfigMap → no restart → change annotation → rollout → new config applied ✅
