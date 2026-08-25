## The Problem: How Do Pods Communicate?
In Kubernetes, applications run inside **pods**, and these pods are **ephemeral**—they can be created, destroyed, and rescheduled dynamically. This introduces two major challenges:  

### Challenge 1: Pod IPs Keep Changing
- Every time a pod is restarted, it gets **a new IP address**.  
- If another pod wants to communicate with it, **hardcoding the IP won’t work** since it keeps changing.  

### Challenge 2: Pods Need to Expose Their Services
- Some pods need to be **accessible from other pods within the cluster** (internal communication).  
- Some pods need to be **accessible from outside the cluster** (external communication).  
- Kubernetes doesn’t automatically handle this, so we need a way to ensure reliable **pod-to-pod and external access**.  

### Challenge 3: Load Balancing
### Challenge 4: Service Discovery



## The Solution: Kubernetes Services 
![Alt text](/images/12a.png)
* A **Kubernetes Service** acts as a **stable communication endpoint** for pods. It provides:  
* Services enable **communication between different components** within and outside the application.
* They **connect applications together** or allow users to access them.
* Services are Kubernetes objects, just like Pods, Deployments, Statefullsets, RC or ReplicaSets.
* You define it in YAML and submit it to the API server.
* Service selects pods based on labels.
* Because Pod IPs are not stable, we use a **Service** to provide a stable way to communicate with Pods.
* **A fixed IP and DNS name** so that pods can always be found, even if their individual IPs change.  
* **Load balancing** across multiple pod replicas to distribute traffic evenly.  
* **Internal and external communication**—services allow pods to communicate **within the cluster** and expose applications **to the outside world** when needed.  
* Example: An application may have:
  * Front-end pods (serve users)
  * Back-end pods (process data)
  * Pods connecting to an external database
* **Services handle connectivity** between these pods:
  * Front-end ↔ Back-end
  * Front-end ↔ Users
  * Back-end ↔ External data source

![image](https://github.com/piyushsachdeva/CKA-2024/assets/40286378/e768b073-dd7b-478a-bbea-ad6acae18051)