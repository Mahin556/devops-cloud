# **Understanding LoadBalancer Service in Kubernetes**  

### **What is a LoadBalancer Service?**  
A **LoadBalancer service** provides a **single, external IP address** to expose applications to the **internet**. It **builds on top of NodePort and ClusterIP services**, offering **automatic load balancing and failover**.  

### **Analogy:**  

![Alt text](/images/12g.png)
![image](https://github.com/piyushsachdeva/CKA-2024/assets/40286378/8f5acc88-4394-47e9-a3c5-041d396166d0)

To make understanding **Kubernetes Services** easier, we'll use an **office building complex analogy** throughout this guide. Here's how the analogy maps to Kubernetes concepts:  

| **Analogy Component**           | **Kubernetes Concept**                                      |  
|--------------------------------|-------------------------------------------------------------|  
| **Office Building Complex**     | **Kubernetes Cluster**                                      |  
| **Individual Buildings**        | **Nodes (Worker/Control Plane Nodes)**                      |  
| **Departments (HR, Finance)**   | **Pods (Running Containers)**                               |  
| **Internal Phone Extensions**   | **ClusterIP Services (Internal Communication)**             |  
| **Front Desk Phone Numbers**    | **NodePort Services (External Access to Nodes)**            |  
| **Call Center**                 | **LoadBalancer Service (Single External IP)**               | 

A **call center** is now set up to manage external calls:  

- The **call center** has a **single, easy-to-remember phone number**.  
- When a **user wants to reach the HR department**, they **call the call center**.  
- The **call center** automatically directs the call to **any healthy building’s front desk**.  
- The **front desk receptionist** then uses the **internal extension** to connect the call to the **HR department**.  

### **Relating to Kubernetes:**  
A **LoadBalancer service** provides a **single external IP address** and **automatically distributes incoming traffic** to **any available NodePort service** in the cluster, ensuring **high availability**.  

```plaintext
User → Call Center (LoadBalancer) → Any Front Desk (NodePort) 
      → Extension 10 (ClusterIP) → HR (Pod)
```
- Available on **cloud providers** (AWS, GCP, Azure, etc).
- When you create a **LoadBalancer service**, Kubernetes requests a **public IP** from the **cloud provider** (e.g., AWS, GCP, Azure).  
- This **public IP** is linked to the **LoadBalancer**, which then **routes traffic** to a **NodePort service** within the cluster.  
- The **NodePort service** internally uses a **ClusterIP service** to **distribute traffic** to the **pods**.  
- Operates at transport layer (TCP).
- Integrates with cloud provider load balancers.
- Ingress is a more advanced alternative at application layer (HTTP/HTTPS) for smarter routing.


## **LoadBalancer Service Manifest Example**  

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80         # ClusterIP Service port
      targetPort: 80    # Container port inside the pod
      nodePort: 31000   # Exposing service on this NodePort (must be within 30000-32767)
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer-service
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

### **How This Works Behind the Scenes:**  

![Alt text](/images/12h.png)

```plaintext
<LoadBalancer External IP>:80 → NodePort (31000) 
                           → ClusterIP (80) → Pod (80)
```

1. **LoadBalancer Service:** Requests a **public IP** from the **cloud provider**.  
2. **NodePort Service:** Exposes the service on **port 31000** across **all worker nodes**.  
3. **ClusterIP Service:** Manages **internal communication** between **pods**.  
4. **Pods:** Handle the **request on port 80**, serving the **application**.  

**Important Note:** You typically won't see **LoadBalancer services** used directly in production, as the load balancing requirements of modern applications are often more complex. Instead, you'll usually find **Ingress Controllers** being used, as they offer advanced traffic management features like URL-based routing, SSL termination, and host-based routing. We'll explore Ingress Controllers in detail later in this course. 

---

### **LoadBalancer (Single Public IP with Automatic Failover)**  
```plaintext
User → Call Center (LoadBalancer) → Any Available Front Desk (NodePort) 
      → Extension 10 (ClusterIP) → HR (Pod)
```