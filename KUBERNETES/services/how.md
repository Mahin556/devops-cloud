## Example: How Services Enable Communication in Kubernetes

Let’s say we have a **frontend application** that needs to communicate with a **backend API**. Here’s how Kubernetes Services help:  

### Step-1: User Requests the Frontend Application  
- A user visits `https://example.com`.  
- The request is received by **frontend-svc** (Frontend Service).  
- **frontend-svc** forwards the request to one of the running pods in **frontend-deploy**.  

### Step-2: Frontend Communicates with Backend
- The frontend needs data from the backend.  
- The frontend pods do **not know the backend pod IPs** because they are dynamic.  
- Instead, the frontend calls `http://backend-svc` (Backend Service).  
- **backend-svc** forwards the request to one of the backend pods running inside **backend-deploy**.  

## How Services Work Internally

* Pods get **labels** (e.g., `app=myapp`).
* Service uses **selectors** to find matching pods.
* Kubernetes creates **Endpoints object** with IPs of those pods.
* Service forwards traffic → kube-proxy (on each node) sets up iptables/IPVS rules → traffic goes to pod.
* Load balancing: traffic is distributed across pods automatically.

## Visualizing Service-Based Communication

### Without Services (Doesn’t Work)
```
User ---> Frontend Pod (IP keeps changing) ---> Backend Pod (IP keeps changing)
```
Pods can’t reliably communicate because IPs change dynamically.

### **With Services (Works)**
```
User ---> frontend-svc ---> Frontend Pod ---> backend-svc ---> Backend Pod
```
- **frontend-svc** provides a stable entry point for the frontend.  
- **backend-svc** allows frontend pods to reliably communicate with backend pods.  


## **Key Takeways:**  
- Kubernetes **does not provide automatic communication between pods**—we need **Services** to enable **stable, reliable networking**.  
- **Services solve two main problems**:  
  - Pods have **dynamic IPs**, so services provide a **fixed IP and DNS name**.  
  - Services allow **internal communication** between pods and **external access** when needed.  
- **Example:**  
  - A **frontend-service** allows users to access the frontend.  
  - A **backend-service** ensures the frontend can communicate with backend pods.  