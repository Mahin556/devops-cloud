## 🔹 **1. Use for non-sensitive data only**

* **Never store secrets** like passwords, API keys, or TLS private keys in ConfigMaps.
* Use **Secrets** instead, which are base64-encoded and can be encrypted at rest.

---

## 🔹 **2. Keep ConfigMaps small**

* **Maximum size:** 1 MiB (total of all keys and values).
* Large configurations can degrade **etcd performance**.
* For bigger files, use **Volumes** (PersistentVolume or ConfigMap volume) instead putting huge configs as env vars.

---

## 🔹 **3. Use immutable ConfigMaps**

* Setting `immutable: true` prevents accidental modification.
* Helps ensure Pods see **consistent configuration**.
* Example:

```yaml
immutable: true
```

---

## 🔹 **4. Name clearly and consistently**

* Use descriptive names that indicate **purpose, environment, or application**:

  ```text
  dev-db-config
  prod-api-config
  frontend-feature-flags
  ```
* Makes management easier across multiple environments.

---

## 🔹 **5. Version your ConfigMaps**

* Instead of modifying a ConfigMap in-place, create a **new version**:

  ```text
  app-config-v1
  app-config-v2
  ```
* Allows **safe rollouts** and avoids conflicts with running Pods.

---

## 🔹 **6. Mount carefully**

* When mounting ConfigMaps as **volumes**, each key becomes a file.
* Avoid conflicts with **existing container file paths**.
* Use dedicated paths like `/etc/app-config` inside Pods.

---

## 🔹 **7. Monitor updates**

* Pods **do not automatically reload environment variables** from ConfigMaps.
* If using mounted volumes, updates propagate automatically but not instantly.
* Plan for **Pod restarts** or rolling updates if your app relies on ConfigMap values as env vars or command-line arguments.
