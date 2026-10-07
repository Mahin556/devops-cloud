Here are detailed notes and information extracted from the provided transcript on **Cluster Setup – Node Metadata Protection**:

---

## 1. Introduction to Node Metadata Protection

- Focus is on protecting sensitive metadata in cloud-based Kubernetes clusters.
- Two main aspects:
  1. Understanding what cloud metadata is and why it's sensitive.
  2. Restricting access to metadata using **Network Policies**.

---

## 2. Cloud Platform Node Metadata

### What is Metadata?
- When you create virtual machines in a cloud provider (Google Cloud, AWS, Azure), a **metadata server** is automatically provided by the cloud provider.
- The VM can connect to this metadata server to get information about:
  - The environment (e.g., instance ID, hostname, region).
  - The service account credentials attached to the instance.
  - Other configuration data, sometimes including **sensitive credentials**.

### Why is it a Security Concern?
- By default, metadata service API is reachable from the VM.
- It may contain cloud credentials that can be used to provision other resources or access cloud APIs.
- If a pod or container can access the metadata server, it might retrieve those credentials and compromise the cloud account.

### Best Practices Outside Kubernetes
- **Limit permissions** of the cloud instance’s service account (IAM role) so that even if credentials are stolen, damage is minimized.
- Each cloud provider has its own recommendations; some have secure defaults, others require manual tightening.
- This is outside the direct scope of Kubernetes but crucial for overall security.

---

## 3. Restricting Access Using Network Policies

### Problem: Pods Can Access Metadata by Default
- In a self‑managed cluster (e.g., on GCP), worker node VMs can reach the metadata server.
- **Even pods** running on those nodes can typically reach the metadata server **by default** because pods share the node’s network namespace.
- This means an attacker who compromises a container might directly query the metadata server without needing to break out to the node.

### Solution: Use Kubernetes Network Policies
- Network policies can control **egress traffic** from pods.
- You can **deny all pods** access to the metadata IP **except** those with a specific label that are allowed to access it (e.g., system components that legitimately need it).

---

## 4. Demonstration on Google Cloud Platform (GCP)

### Step 1: Access Metadata from the Instance
- Command used (from GCP documentation):
  ```bash
  curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/
  ```
- This returned metadata information, confirming access from the VM itself.

### Step 2: Access Metadata from a Pod
- Created a simple nginx pod:
  ```bash
  kubectl run nginx --image=nginx
  ```
- Executed into the pod and ran the same `curl` command.
- The command succeeded, proving that **pods can access the GCP metadata server by default**.

### Step 3: Create a Deny Network Policy
- The `deny` policy (file: `np-cloud-metadata-deny.yaml`) has:
  - `podSelector: {}` (applies to all pods in the namespace)
  - Egress rule allowing traffic to all IPs **except** the metadata server IP (`169.254.169.254`).
- This effectively blocks all pods from reaching the metadata server.

**Command:**
```bash
kubectl apply -f deny.yaml
```
- After applying, re‑tested the `curl` command inside the nginx pod – it **failed** (timed out or connection refused), confirming the block.

### Step 4: Create an Allow Network Policy
- The `allow` policy (file: `np-cloud-metadata-allow.yaml`) has:
  - `podSelector: matchLabels: role: metadata-accessor`
  - Egress rule allowing traffic **only** to the metadata IP.
- This policy, when combined with the deny policy, effectively overrides the deny for pods that have the label `role=metadata-accessor`.

**Command:**
```bash
kubectl apply -f allow.yaml
```

### Step 5: Label the Pod
- Initially the nginx pod had the label `run=nginx`.
- Added the required label:
  ```bash
  kubectl label pod nginx role=metadata-accessor
  ```
- After labeling, `curl` to the metadata server **worked again**.

### Step 6: Verify by Removing the Label
- Removed the label:
  ```bash
  kubectl label pod nginx role-
  ```
- The `curl` command **failed again**, proving that only pods with the correct label can access the metadata server.

---

## 5. Key Commands Summary

| Action | Command |
|--------|---------|
| Access GCP metadata from VM/pod | `curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/` |
| Create a pod | `kubectl run nginx --image=nginx` |
| Exec into pod | `kubectl exec -it nginx -- /bin/bash` |
| Apply deny network policy | `kubectl apply -f np-cloud-metadata-deny.yaml` |
| Apply allow network policy | `kubectl apply -f np-cloud-metadata-allow.yaml` |
| Label a pod | `kubectl label pod nginx role=metadata-accessor` |
| Remove a label | `kubectl label pod nginx role-` |

---

## 6. Important IP Address

- The GCP metadata server IP used in the demo: `169.254.169.254` (link‑local address).  
- Other cloud providers use different endpoints (AWS: `169.254.169.254`, Azure: `169.254.169.254` or a FQDN). Always check provider documentation.

---

## 7. Recap

- Cloud metadata servers contain sensitive information and are reachable by default from VMs **and** pods.
- Limit cloud IAM permissions to reduce impact of credential theft.
- Use Kubernetes **Network Policies** to:
  - **Deny** egress to metadata server for all pods (default deny).
  - **Allow** only specific pods (e.g., with label `role=metadata-accessor`) to reach it.
- This combination ensures that only trusted workloads can access cloud credentials.

---

These notes capture the core concepts, steps, and commands from the transcript. For further study, refer to the official Kubernetes Network Policies documentation and your cloud provider’s metadata service security recommendations.