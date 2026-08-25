# **Understanding NodePort Service in Kubernetes**  

## **What is a NodePort Service?**  
A **NodePort** service in Kubernetes allows **external access** to pods using a **worker node’s IP address** and a fixed port. Unlike a **ClusterIP** service, which is only accessible **inside the cluster**, a NodePort service makes applications available from **outside the cluster** using the format:  

```plaintext
http://<NodeIP>:<NodePort>
```
### **Analogy:**  

![Alt text](/images/12d.png)
![image](https://github.com/piyushsachdeva/CKA-2024/assets/40286378/8aa9c482-be3a-450a-95b7-0a0c0e80403e)

| **Analogy Component**           | **Kubernetes Concept**                                      |  
|--------------------------------|-------------------------------------------------------------|  
| **Office Building Complex**     | **Kubernetes Cluster**                                      |  
| **Individual Buildings**        | **Nodes (Worker/Control Plane Nodes)**                      |  
| **Departments (HR, Finance)**   | **Pods (Running Containers)**                               |  
| **Internal Phone Extensions**   | **ClusterIP Services (Internal Communication)**             |  
| **Front Desk Phone Numbers**    | **NodePort Services (External Access to Nodes)**            |  


The **office building complex** still has **two buildings** with **four departments** in each: **HR, Finance, Security, and Technology** (**extensions 10, 11, 12, and 13**).  

- Each building now also has a **front-desk phone number**.  
- An **external caller** needs to have the **front desk numbers of both buildings** to ensure they can **reach any department** even if **one building is not functioning**.  
- When an external user calls the **front desk**, the **receptionist** **forwards the call** to the **correct department using internal extensions**.  

### **Relating to Kubernetes:**  
A **NodePort service** exposes **internal ClusterIP services** externally via a **fixed port on each worker node**. If **one node goes down**, the user must **manually switch to another node’s IP**.  


```plaintext
User → Building-1 Front Desk (NodePort) → Extension 10 (ClusterIP) → HR (Pod)

If Building-1 is down:
User → Building-2 Front Desk (NodePort) → Extension 10 (ClusterIP) → HR (Pod)
```

### **Key Characteristics of NodePort Service**
- **External Access** – Allows users outside the cluster to access a service using `NodeIP:NodePort`.  
- **Works Across All Nodes** – The service is available on **every worker node**, regardless of where the actual pods are running.  
- **Built on ClusterIP** – Internally, a **NodePort service forwards requests to a ClusterIP service**, which then routes traffic to the correct pod.  
- **Fixed Port Range (30000-32767)** – NodePort services use a **predefined range** to avoid port conflicts with system and ephemeral ports. This range is configurable, but it’s **best practice** to keep it unchanged unless necessary.  

**Note:**
With both **NodePort** and **LoadBalancer services** (to be discussed later), you can **choose not to explicitly specify the NodePort** in your **YAML manifest**. If you **omit the `nodePort` field**, **Kubernetes** will **automatically assign a port** from the **default NodePort range (30000-32767)**.  

However, in this course, I have **explicitly defined the NodePort as `31000`** in **all examples**. This is because we are using a **KIND (Kubernetes IN Docker) cluster**, and our **KIND configuration** only **exposes port 31000** to the **host machine**. This configuration ensures that **external access works consistently** and **avoids potential port conflicts**.  

By **manually specifying the port**, we maintain **control and predictability** over the **service exposure**, which is especially **important for learning environments** and **local testing scenarios**.


### **Exposing a Frontend Application Using a NodePort Service**  

Let's deploy a **frontend application** and expose it using a **NodePort service**.  

### **Step 1: Frontend Deployment (`frontend.yaml`)**
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
      containers:
      - name: frontend-container
        image: nginx:latest
        ports:
        - containerPort: 80  # NGINX serves content on port 80
```

### **Step 2: Frontend NodePort Service (`frontend-service.yaml`)**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80         # ClusterIP service port
      targetPort: 80   # Container's port inside the pod
      nodePort: 31000  # Exposed externally (must be in 30000-32767)
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  labels:
    k8s-app: myapp
spec:
  type: NodePort
  selector:
    k8s-app: myapp
    component: nginx
    env: production
  ports:
    - name: web
      protocol: TCP
      port: 8080        # Service port
      targetPort: 80    # Pod container port
      nodePort: 31999   # Fixed NodePort
```

This service exposes the frontend using the NodePort **`31000`** on all worker nodes.

## **How a NodePort Service Handles Requests (Step-by-Step Flow)**  

![Alt text](/images/12e.png)

Let’s assume:  
- A worker node has the IP **172.18.0.4**.  
- The **NodePort is 31000**.  
- The **ClusterIP assigned to `frontend-svc` is `10.96.45.120`**.  
- A **frontend pod (`frontend-pod3`) has the IP `10.244.2.10`**.  

### **Request Flow:**
1. **User accesses the frontend service using**:  
   ```plaintext
   http://172.18.0.4:31000
   ```
2. The NodePort service (`frontend-svc`) listens on all worker nodes and forwards the request to its ClusterIP (`10.96.45.120:80`).  
3. The ClusterIP service load balances the request and forwards it to a running frontend pod (e.g., `frontend-pod3` at `10.244.2.10:80`).  
4. The frontend pod processes the request and responds back to the user.

**Because the NodePort service is available on all worker nodes, the user could also access the frontend using any other worker node’s IP, for example:**  
```sh
curl http://172.18.0.5:31000
```
---
* Expose a Deployment externally (NodePort)
```bash
kubectl expose deployment my-deployment --port=80 --target-port=8080 --type=NodePort
```
- Service gets a random port between 30000–32767
- You can access it using <NodeIP>:<NodePort>

* Expose with a fixed NodePort
```bash
kubectl expose deployment my-deployment --port=80 --target-port=8080 --type=NodePort --name=my-service --overrides='
{
  "spec": {
    "ports": [{
      "port": 80,
      "targetPort": 8080,
      "nodePort": 31000
    }]
  }
}'
```

* Expose a ReplicaSet
```bash
kubectl expose rs my-replicaset --port=80 --target-port=8080
```

```bash
kubectl expose pod nginx1 --port=80 --target-port=80 --type=NodePort --name=my-service1 --dry-run=server -ojson
{
    "kind": "Service",
    "apiVersion": "v1",
    "metadata": {
        "name": "my-service1",
        "namespace": "default",
        "uid": "33342579-ccd4-405b-acdb-f7144751f097",
        "creationTimestamp": "2025-09-30T15:35:08Z",
        "labels": {
            "run": "nginx1"
        }
    },
    "spec": {
        "ports": [
            {
                "protocol": "TCP",
                "port": 80,
                "targetPort": 80,
                "nodePort": 32769
            }
        ],
        "selector": {
            "run": "nginx1"
        },
        "clusterIP": "10.96.0.0",
        "clusterIPs": [
            "10.96.0.0"
        ],
        "type": "NodePort",
        "sessionAffinity": "None",
        "externalTrafficPolicy": "Cluster",
        "ipFamilies": [
            "IPv4"
        ],
        "ipFamilyPolicy": "SingleStack",
        "internalTrafficPolicy": "Cluster"
    },
    "status": {
        "loadBalancer": {}
    }
}
```

---

### **NodePort (External Access with Manual IP Management)**  
```plaintext
User → Building-1 Front Desk (NodePort) → Extension 10 (ClusterIP) → HR (Pod)

If Building-1 is down:
User → Building-2 Front Desk (NodePort) → Extension 10 (ClusterIP) → HR (Pod)
```