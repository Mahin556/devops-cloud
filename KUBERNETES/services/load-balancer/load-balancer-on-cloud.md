### 1. **Prerequisites**

* A running Kubernetes cluster (cloud-based or on-premises).
* `kubectl` configured to interact with the cluster.
* A deployment or pods that you want to expose via the load balancer.

---

### 2. **Create a Deployment**

First, create a deployment to have a set of pods that the load balancer will route traffic to. For example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 5
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp-container
        image: webapp-image:latest
        ports:
        - containerPort: 8080
```

* `replicas: 5` → Creates 5 pods.
* Pods are labeled `app: webapp`, which will be used by the load balancer to select them.

---

### 3. **Configure a LoadBalancer Service**

Now create a service of type `LoadBalancer`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80         # Port exposed externally
    targetPort: 8080 # Port on the pods
```

**Explanation:**

* `type: LoadBalancer` → Tells Kubernetes to provision an external load balancer (cloud provider required).
* `selector: app: webapp` → Links the service to the deployment pods.
* `port` → External port on the load balancer.
* `targetPort` → Port on which the pod container listens.

---

### 4. **View LoadBalancer IP**

```bash
kubectl get services webapp-service
```

* Cloud providers automatically provision the external IP.
* On local/on-prem clusters (like Minikube), NodePort or ingress may be required instead.

---

### 5. **Internal LoadBalancer (Cluster-only access)**

* **AWS Example:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

* `annotations` → Marks the LB as internal.

* `externalTrafficPolicy: Local` → Only nodes in the cluster handle the traffic.

* **GCP Example:**

```yaml
annotations:
    cloud.google.com/load-balancer-type: "Internal"
```

* **Azure Example:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.1
  loadBalancerSourceRanges:
  - 192.168.2.0/24
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

* `loadBalancerIP` → Assigns a specific internal IP.
* `loadBalancerSourceRanges` → Restricts access to specific IP ranges.

---

### 6. **Using kubectl to Create a LoadBalancer**

You can also create a LoadBalancer service directly from the CLI:

```bash
kubectl create service loadbalancer webapp-service --tcp=80:8080
```

* To generate YAML for modification:

```bash
kubectl create service loadbalancer webapp-service --tcp=80:8080 --dry-run=client -o yaml
```

---

### 7. **How It Works**

1. LoadBalancer service provisions an external IP (cloud provider handles it).
2. Routes external traffic on port 80 to the selected pods’ `targetPort`.
3. Works with `ClusterIP` internally to distribute traffic among pods.
4. Internal load balancers restrict traffic within the cluster using annotations.


### References:
- https://spacelift.io/blog/kubernetes-load-balancer