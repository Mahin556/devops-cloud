* Centrally and externally manage and use in diff pods and containers.
* Decouple configuration from the application logic.
* Make Container image flexible for different environment.
* To share configuration between multiple Pods.
* To dynamically update configurations (when combined with volume mounts and rolling updates).
* Storing `.env` or `.properties` files for microservices
* To manage multiple environment-specific settings.
* Improve portability across environments (dev, test, prod) env specific
    ```bash
    configmap-dev.yaml
    configmap-prod.yaml
    ```
* Cross-Cluster Configuration Migration
    ```bash
    kubectl get configmap app-config -o yaml > backup.yaml
    kubectl apply -f backup.yaml --context new-cluster
    ```

---
Containers make your application code portable across environments — but configuration data (like database hosts or API endpoints) is often environment-specific.

If those configurations are baked into your container images:

You can’t reuse the same image in another environment without modification.

Small configuration changes require a full rebuild and redeploy.

Portability — the whole point of containers — is lost.

Enter ConfigMaps.
Kubernetes ConfigMaps allow you to externalize configuration data so containers can stay portable while their environment-specific settings remain flexible.
---

### References:
- https://www.geeksforgeeks.org/devops/kubernetes-config-map-from-directory/
- https://www.groundcover.com/blog/kubernetes-configmap