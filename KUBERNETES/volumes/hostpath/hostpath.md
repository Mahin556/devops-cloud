### References:
- [Day 27: Kubernetes Volumes | Persistent Storage | PV, PVC, StorageClass, hostPath DEMO](https://www.youtube.com/watch?v=C6fqoSnbrck&ab_channel=CloudWithVarJosh)
- [Kubernetes Documentation on hostPath](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath).
- https://spacelift.io/blog/kubernetes-persistent-volumes


---

* `hostPath` is a Kubernetes volume type that mounts a file or directory from the underlying node’s filesystem into a Pod.
* `hostPath` volumes are **node-specific**, meaning they are limited to the node where the Pod is scheduled. All Pods running on the same node can access and share data stored in a `hostPath` volume. However, since each node has its own independent storage, **Pods on different nodes cannot share the same `hostPath` volume**, making it unsuitable for distributed workloads requiring cross-node data sharing.
* Defined inside the Pod spec itself.
* The directory/file is created directly on the worker node’s filesystem.
* Tightly coupled → if the pod moves to another node, the data does not follow.
* This means the Pod gets direct access to the host’s actual files.
* **Where is hostPath used?**
  * Debugging or troubleshooting (mount /var/log or /etc)
  * Storing logs directly on the node
  * Device access in special workloads (GPU drivers, Kubelet plugins)
  * Injecting config files to the static pods because (static pods cannot use ConfigMaps)
  * Single-node clusters (Minikube, Docker Desktop)
  * Legacy applications needing local node paths
  * Path-based CSI driver development
  * Mount /var/log from the node → Pod can read host logs
  * Mount /etc/hosts → Pod can read system config
  * Mount /dev/null → Pod can access host device
  * Accessing host binaries (mount /usr/bin or /bin/docker)
  * Mount /var/run/docker.sock → Pod can control Docker daemon

- Mounts a directory from the node directly into the pod.
- Primarily used for testing or simple workloads.
- In-tree only; there is no CSI implementation.
- **Caution:** Unsuitable for production due to security risks(malicious) and lack of scheduling guarantees.
  
* **Why is it Used?**  
  * It is used for scenarios such as debugging, accessing host-level files (logs, configuration files), or sharing specific host resources with containers.

* **Why Kubernetes Recommends Avoiding `hostPath`**  
  * Pod can access host system files(sensitive host files is `hostPath` is misconfigured) 
    * Access kubelet credentials
    * Access container runtime (Docker/Containerd)
    * Access host’s /etc, /var/lib/kubelet, /root, /proc
  * Since `hostPath` is tied to a node, it reduces flexibility in scheduling.  
  * Inject malicious files
  * Break out of container
  * Take control of the entire node
  * **Better Alternatives**: Kubernetes recommends using **PersistentVolumes (PV) with PersistentVolumeClaims (PVC)** or **local PersistentVolumes**, which offer better control and security.
  * Using hostPath for database storage.


> With `emptyDir`, all containers **within a single pod** can access the shared volume, but it is **not accessible to other pods**.  
> With `hostPath`, **any pod running on the same node** that mounts the same host directory path can access the same volume data, thus enabling **cross-pod sharing on the same node**.




