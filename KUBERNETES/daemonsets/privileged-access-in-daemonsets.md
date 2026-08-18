### 🔹 Why Privileged Access in DaemonSets?

* **CNI plugins (Calico, Flannel, Cilium):** Need to configure routing tables, `iptables`, kernel modules → requires **privileged mode**.
* **kube-proxy:** Manages network rules, NAT → requires privileged mode.
* **Storage DaemonSets (Ceph, GlusterFS):** Need to mount volumes on the host.
* **Monitoring Agents (Node Exporter, Fluentd, Prometheus):** Sometimes need host PID/Network access.

---

### 🔹 Pod-level vs Container-level Security Context

* **Pod-level `securityContext`:**

  * Applies defaults to *all containers* in the Pod.
  * Example: enforce `runAsNonRoot: true` for every container.

* **Container-level `securityContext`:**

  * Fine-grained — applies to a specific container.
  * Example: one container may run as **privileged**, while others don’t.

---

### 🔹 Example: Privileged DaemonSet (like Calico or kube-proxy)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: kube-proxy
  template:
    metadata:
      labels:
        k8s-app: kube-proxy
    spec:
      hostNetwork: true   # Pod shares host’s network namespace
      serviceAccountName: kube-proxy
      priorityClassName: system-node-critical
      dnsPolicy: ClusterFirstWithHostNet
      terminationGracePeriodSeconds: 30
      updateStrategy:
        type: RollingUpdate
        rollingUpdate:
          maxUnavailable: 1
      tolerations:
      - operator: Exists   # Run on all nodes, even tainted ones
      containers:
      - name: kube-proxy
        image: k8s.gcr.io/kube-proxy:v1.28.0
        securityContext:
          privileged: true                # FULL privileged access
          allowPrivilegeEscalation: true  # Can gain extra privileges
          runAsUser: 0                    # Runs as root
        volumeMounts:
        - mountPath: /lib/modules
          name: lib-modules
          readOnly: true
      volumes:
      - name: lib-modules
        hostPath:
          path: /lib/modules
```
* The `hostNetwork: true` and `privileged: true` settings are required for kube-proxy, since it interacts with iptables and host networking.
* The tolerations with operator: Exists ensures it runs on all nodes, including tainted control-plane nodes — good for cluster-wide networking.
* The /lib/modules volume mount is correct for kernel module access.
---

### 🔹 Common SecurityContext Fields

* `privileged: true` → gives **root-equivalent host access**.
* `allowPrivilegeEscalation: false` → prevents SUID binaries from escalating privileges (recommended unless needed).
* `runAsNonRoot: true` → enforce non-root.
* `runAsUser: 1000`, `runAsGroup: 3000` → force container processes to run as specific UID/GID.
* `readOnlyRootFilesystem: true` → makes root FS read-only, improving security.

---

### 🔹 Best Practices for Privileged DaemonSets

* Use `privileged: true` **only if strictly required** (network/storage DaemonSets).
* Use **PodSecurityPolicy** (PSP) or **Pod Security Admission** to restrict privileged containers.
* Limit privileges per container (e.g., only kube-proxy, not sidecars).
* Always **scope DaemonSets to namespaces** (`kube-system`, `logging`, etc.).
* Use **tolerations + nodeSelector/affinity** to run privileged Pods only where needed.

### References:
- https://devopscube.com/kubernetes-daemonset/