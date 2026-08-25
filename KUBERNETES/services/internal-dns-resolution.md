## Internal DNS Resolution (Cluster Communication)
* Kubernetes uses **CoreDNS** for service discovery.
* Pods can reach the service using its **name**:
  ```
  http://<service-name>
  e.g., http://nginx-service
  ```
* CoreDNS resolves the service name to its **ClusterIP**, which then routes traffic to the correct Pod.
