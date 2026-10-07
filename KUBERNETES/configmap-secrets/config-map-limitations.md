## 🔹 **1. Size Limits**

* **Maximum size:** 1 MiB per ConfigMap (all keys + values combined).
* **Reason:** ConfigMaps are stored in **etcd**, which has strict size and performance constraints.
* **Impact:**
  * Large ConfigMaps can slow down etcd and Kubernetes API server operations.
  * If you need larger configs, consider **mounting files from a volume (like PersistentVolume)** or using **Secrets** for smaller sensitive data.

---

## 🔹 **2. Data Type Restrictions**

* ConfigMaps store **only string key-value pairs**.
* **Non-string data (integers, booleans, JSON)** must be serialized to strings.
* **Examples:**
  ```yaml
  data:
    max_connections: "100"        # integer as string
    feature_enabled: "true"       # boolean as string
    settings_json: '{"a":1,"b":2}' # JSON as string
  ```
* Applications must parse these strings if they need actual types.

---

## 🔹 **3. Mounting Limits**

* Each ConfigMap key becomes a **separate file** in the container when mounted as a volume.
* Filesystem limitations can affect you:
  * Maximum number of files (inode limit)
  * Maximum filename length
  * Maximum directory depth

* **Tip:** Keep the number of keys reasonable and avoid deeply nested mounts.

---

## 🔹 **4. Versioning and Updates**

* ConfigMaps **do not support versioning natively**.
* **Environment variables:**
  * Pods **must restart** to pick up changes.
* **Command-line arguments:**
  * Pods **must restart**.
* **Mounted volumes:**
  * Updates may propagate automatically via the Kubelet, but not instantaneously.
  * Applications may need to **watch the files or reload configuration**.

* **Tip:** Use versioned ConfigMap names (`app-config-v1`, `app-config-v2`) and update Deployments to point to new versions for predictable rollouts.

---

## 🔹 **5. Management Considerations**

* Tools like **Spacelift** or **GitOps pipelines** can help:
  * Track ConfigMap changes in version control.
  * Automate updates and rolling restarts.
  * Ensure consistent configuration across environments.
