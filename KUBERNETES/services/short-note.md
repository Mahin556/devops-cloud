- **ClusterIP:** Allows **internal-only communication** between pods.  
- **NodePort:** Adds **external access** through a **specific port on each node's IP**, but requires **manual switching** if a **node goes down**.  
- **LoadBalancer:** Provides a **single public IP** with **automatic load balancing**, ideal for **production environments**.  
- **ExternalName:** Offers a **simple alias** to connect **internal services to external resources** using **DNS names**.  
- When using **ExternalName**, applications **connect to services using internal DNS names**, and **Kubernetes handles the external redirection**.  
- This **separates configuration from application logic**, ensuring **easier maintenance** and **flexibility**.  

----

## Best Practices
* Always use **labels + selectors** consistently.
* For multiple ports, always **name ports**.
* Use **ClusterIP** for internal communication, **NodePort/LoadBalancer/Ingress** for external.
* In production, prefer **LoadBalancer + Ingress** for external access instead of raw NodePorts.

