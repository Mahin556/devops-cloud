## Understanding ClusterIP Service in Kubernetes

### What is a ClusterIP Service?
A **ClusterIP** service is the default type of Kubernetes service that exposes applications **internally** within the cluster. It allows communication between different pods using an automatically assigned **internal IP address**, making it ideal for inter-service communication.
A **ClusterIP Service** exposes a stable **virtual IP (ClusterIP)** inside the cluster.
Also called **Service IP**.

### **Analogy:**  
![Alt text](/images/12b.png)
![image](https://github.com/piyushsachdeva/CKA-2024/assets/40286378/3817a5e7-5208-41c8-9dee-d4c052038151)
![Alt Text](/images/cpi1.png)

Analogy:-

| **Analogy Component**           | **Kubernetes Concept**                                      |  
|--------------------------------|-------------------------------------------------------------|  
| **Office Building Complex**     | **Kubernetes Cluster**                                      |  
| **Individual Buildings**        | **Nodes (Worker/Control Plane Nodes)**                      |  
| **Departments (HR, Finance)**   | **Pods (Running Containers)**                               |  
| **Internal Phone Extensions**   | **ClusterIP Services (Internal Communication)**             |  
 

There is an **office building complex** with **two buildings**: **Building-1** and **Building-2**. Each building has **four departments**: **HR, Finance, Security, and Technology**, with **extensions 10, 11, 12, and 13**, respectively.  

- The **HR department** can reach the **Finance department** by **dialing extension 11**, and so on.  
- This **internal phone system** only works **within the building complex**—no **external calls** are allowed.  

### **Relating to Kubernetes:**  
A **ClusterIP service** allows **pods within the cluster** to communicate with each other using **internal-only IPs**, much like using **internal extensions** within the office complex.  

```plaintext
HR (Pod) → Extension 11 (ClusterIP) → Finance (Pod)
```

### **Key Characteristics of ClusterIP Service**  
- **Internal-Only Access** – The service is accessible **only within the Kubernetes cluster** and cannot be reached from outside.  
- **Automatic DNS Resolution** – Kubernetes assigns a **stable DNS name** (e.g., `backend-svc`) that other pods can use instead of an IP address.  
- **Load Balancing Across Pods** – kube-proxy **distributes traffic** among the healthy backend pods associated with the service.  
- **Simplifies Pod Communication** – Enables seamless **service-to-service** communication without requiring pod IPs, which are dynamic and can change.  

## **Example: Demonstrating ClusterIP with Frontend (NGINX) and Backend (http-echo)**  

![Alt text](/images/12c.png)

### **Architecture Overview**  
We will create a **two-tier application** where:  
1. **Frontend:** Runs an NGINX container on port 80.  
2. **Backend:** Runs a simple HTTP server using the `hashicorp/http-echo` image on port 5678. This server responds with a static message.  

### **How the Frontend Communicates with the Backend**  
- The frontend pods (NGINX) will communicate with the backend using the service name **`backend-svc:9090`**.  
- **CoreDNS** resolves `backend-svc` to its ClusterIP (e.g., `10.96.26.155`).  
- The request is then forwarded to one of the backend pods by **kube-proxy**.  
- In our example the request is forwarded to the 3rd pod (`10.244.2.23:5678`)

## **Deploying the Frontend and Backend**  

### **Frontend Deployment (NGINX)**  
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
          image: nginx
```

### **Backend Deployment (http-echo)**  
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
      containers:
      - name: backend-container
        image: hashicorp/http-echo
        args:
          - "-text=Hello from Backend"
```

### **Backend Service (ClusterIP)**  
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  type: ClusterIP #Optional
  ports:
    - protocol: TCP #Optional default TCP
      port: 9090  # Exposed Service Port
      targetPort: 5678  # Container Port
  selector:
    app: backend
```
* Front end pod can access backend pods using http://backend-service:9090` (inside cluster only).

## **Key Takeaways:**  
- A **ClusterIP service** is used for **internal** communication within a Kubernetes cluster.  
- **CoreDNS** resolves service names to their **ClusterIP**.  
- **kube-proxy** manages traffic routing and load balances requests across multiple backend pods.  
- This example demonstrated how an NGINX frontend interacts with an HTTP backend using a ClusterIP service.  

---

### **ClusterIP (Internal-Only Communication)**  
```plaintext
HR (Pod) → Extension 11 (ClusterIP) → Finance (Pod)
```