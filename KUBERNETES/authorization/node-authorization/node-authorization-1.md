**Special-purpose authorization mode exclusively for kubelets.**
* Node Authorization is an authorization mode designed specifically for **kubelets**, the agent running on every Kubernetes node.
* It protects the API server by ensuring that kubelets can only:
    * Read the **Pods assigned to their node**
    * Access **Secrets** or **ConfigMaps** needed by those Pods
    * Read/modify node-specific resources
    * Adjust status fields of Pods running on their node
* To enforce the **Principle of Least Privilege** for kubelets.
* Without Node Authorization, kubelets would have too much power and could:
    * Read secrets for all namespaces
    * Access pods on other nodes
    * Modify cluster-wide resources
* Node authorization ensures each node can only manage **its own resources**, nothing more.
* In kube-apiserver:
    ```bash
    --authorization-mode=Node,RBAC
    ```
