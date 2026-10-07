# ⚙️ **How to Manage Kubernetes Secrets**

To securely handle sensitive information stored in Kubernetes Secrets, follow these **best practices**:

### 1️⃣ **Creation**

* Use `kubectl` or YAML manifests to create Secrets for passwords, tokens, or certificates.

  ```bash
  kubectl create secret generic my-secret --from-literal=password=myPass123
  ```

### 2️⃣ **Access Control**

* Implement **RBAC (Role-Based Access Control)** to restrict who can **view, modify, or mount** Secrets.
  Example: only specific ServiceAccounts or roles should have access.

### 3️⃣ **Encryption**

* Enable **encryption at rest** for Secrets in `etcd`.
* Consider using **external secret managers** (e.g., HashiCorp Vault, AWS Secrets Manager) to enhance security.

### 4️⃣ **Rotation**

* Regularly **rotate credentials and tokens** to minimize exposure risk and meet compliance standards.

