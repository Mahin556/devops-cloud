# Types of Kubernetes Services

1. **NodePort**
   * Makes a Pod accessible on a port of the Kubernetes node.
   * Acts as a **bridge** to access Pods from outside the cluster.

2. **ClusterIP** (default)
   * Creates a **virtual IP inside the cluster**.
   * Enables communication between services (e.g., web server ↔ database server).

3. **LoadBalancer**
   * Provisions a **cloud provider load balancer** for your application.
   * Distributes traffic across multiple nodes/pods.

4. **External Name**
  * CNAME
