As modern applications grow in complexity, separating configuration and secrets from application logic becomes essential for portability, maintainability, and security. Kubernetes provides native support for this through **ConfigMaps** and **Secrets**. ConfigMaps help manage non-sensitive configuration data, while Secrets handle sensitive data like passwords and API keys.

In this session, we will learn how to use ConfigMaps and Secrets effectively in Kubernetes. Through hands-on demos, you’ll explore injecting configurations as environment variables, command-line arguments, and files, and understand how Kubernetes handles updates to these objects at runtime. You’ll also learn the key differences between ConfigMaps and Secrets, and best practices for secure and scalable usage in real-world environments.

---

## ConfigMaps

### **Why Do We Need ConfigMaps?**

In real-world Kubernetes deployments:

- Maintaining a large number of hardcoded environment variables in Pod specs can become unmanageable.
- You may want to update configuration without rebuilding your container image.
- You might need to inject configuration data via environment variables, CLI arguments, or mounted files.
- We don't want to hardcode any thing any configuration in our application containers.
- Decoupling
- Prevent image updation again and again
- Inject config data into app
- Store non-sensitive configuration outside of pod in key-value pair.

**ConfigMaps** allow you to **decouple configuration from your container images**, making your applications more portable and easier to manage.

---

### **What is a ConfigMap?**

A **ConfigMap** is a Kubernetes API object used to store **non-confidential key-value configuration data**. 

Pods can consume ConfigMaps in three primary ways:

1. As **environment variables**
2. As **command-line arguments** (Less Common)
3. As **configuration files via mounted volumes**

> **Important:** ConfigMaps do not provide encoding. For sensitive information, use a **Secret** instead.

![](/images/image4.png)


**What are Environment Variables?**

Environment variables are key-value pairs used by the operating system and applications to store configuration settings. They help control how processes behave without modifying the underlying code.

**Example on a Linux system:**

```bash
export APP_NAME=frontend
export ENVIRONMENT=production
```

You can access these values using the `echo` command:

```bash
echo $APP_NAME     # Output: frontend
echo $ENVIRONMENT  # Output: production
```

These variables are commonly used in shell scripts or passed to applications during execution to configure them dynamically.

---

### **Without ConfigMap: Hardcoded Environment Variables**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend-container
          image: nginx
          env:
            - name: APP
              value: frontend
            - name: ENVIRONMENT
              value: production
```

While this works, hardcoding environment variables is not scalable or reusable across environments.
If you change a Value of Env and reapply it deloyment recreate a pod in rolling manner(default)

Defining
Injecting
---

## **Demo 1: Using ConfigMap as Environment Variables**

For this demo, we’ll build on the `frontend-deploy` configuration introduced in **Day 12** of this course. If you'd like a deeper understanding of **Kubernetes Services**, feel free to explore the following resources:

- [Day 12 GitHub Notes](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025/tree/main/Day%2012)

- [Day 12 YouTube Video](https://www.youtube.com/watch?v=92NB8oQBtnc)

### Step 1: Create ConfigMap

```yaml
apiVersion: v1  # Defines the API version for the Kubernetes object.
kind: ConfigMap  # Declares this resource as a ConfigMap.
metadata:
  name: frontend-cm  # The name used to reference this ConfigMap in pods or other resources.
data:
  APP: "frontend"  # Key-value pair representing configuration data (e.g., application name).
  ENVIRONMENT: "production"  # Key-value pair used to define the deployment environment.

```

Apply:

```bash
kubectl apply -f frontend-cm.yaml
```

> **Note:** Always apply the **ConfigMap before the Deployment**, so that the pods can reference and consume the configuration data during startup.
> Run sequence must correct.

---

### Step 2: Reference ConfigMap in Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy  # Name of the Deployment resource
spec:
  replicas: 3  # Number of pod replicas to maintain
  selector:
    matchLabels:
      app: frontend  # Selector to match pods managed by this Deployment
  template:
    metadata:
      labels:
        app: frontend  # Label assigned to pods created by this Deployment
    spec:
      containers:
      - name: frontend-container  # Name of the container within each pod
        image: nginx  # Using the official Nginx image
        env:
        - name: APP  # Environment variable name inside the container
          valueFrom:
            configMapKeyRef:
              name: frontend-cm  # Name of the ConfigMap from which the value is pulled
              key: APP  # Key in the ConfigMap whose value is used for this environment variable
        - name: ENVIRONMENT  # Another environment variable inside the container
          valueFrom:
            configMapKeyRef:
              name: frontend-cm
              key: ENVIRONMENT

        # NOTE:
        # The value of key "APP" will be picked up from the key "APP" in the ConfigMap named "frontend-cm".
        # The 'name' field here (APP) is the environment variable name that will be visible inside the container.
        # It does NOT need to match the 'key' from the ConfigMap.
        # For example:
        # - You could write: name: SERVICE and key: APP
        # - Inside the container, the environment variable would be called SERVICE and hold the value of APP from the ConfigMap.
```

Apply:

```bash
kubectl apply -f frontend-deploy.yaml
```

---

### Verification

Pick a Pod from the Deployment:

```bash
kubectl get pods -l app=frontend
```

Then exec into one of them:

```bash
kubectl exec -it <pod-name> -- printenv | grep -E 'APP|ENVIRONMENT'
```

Expected Output:

```
APP=frontend
ENVIRONMENT=production
```

* If we change now in ConfigMap and reapply(configmap and pod) if it will not recreate a pods(pods have same age) to apply change(update):
```bash
kubectl rollout restart deployment demo1
```
---

**NOTE:** I forgot to cover this in the demo, but you can also **create a ConfigMap imperatively** using the `kubectl create configmap` command.  
For example:

```bash
kubectl create configmap <name-of-configmap> --from-literal=key1=value1 --from-literal=key2=value2
```

A real-world example would be:

```bash
kubectl create configmap frontend-cm --from-literal=APP=frontend --from-literal=ENVIRONMENT=production
```

> This method is quick and useful for creating simple ConfigMaps **imperatively** from the command line, without needing to write and apply a YAML manifest.

**When to Use Imperative vs Declarative Approach**

- **Imperative Commands (`kubectl create configmap`)** are best when you:
  - Need to quickly create a ConfigMap for testing or small demos.
  - Are experimenting or working interactively.
  - Don't need to track the resource in version control (like Git).

- **Declarative Approach (YAML manifests + `kubectl apply -f`)** is preferred when you:
  - Are working in production environments.
  - Want your ConfigMaps (and all Kubernetes resources) to be version-controlled.
  - Need better team collaboration, auditing, and repeatable deployments.

> **Rule of Thumb:**  
> Use **imperative** for quick, temporary tasks.  
> Use **declarative** for production-grade, repeatable, and auditable setups.

---

## **Demo 2: Using ConfigMap as a Configuration File (Volume Mount)**

For this demo, we’ll build on the `frontend-deploy` configuration introduced in **Day 12** of this course. If you'd like a deeper understanding of **Kubernetes Services**, feel free to explore the following resources:

- [Day 12 GitHub Notes](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025/tree/main/Day%2012)

- [Day 12 YouTube Video](https://www.youtube.com/watch?v=92NB8oQBtnc)

- The config map as a volume mounted to the pod dynamically means if we change in config map we can see realtime change inside the pod(not need to recreate)

### Step 1: Modify ConfigMap to Include HTML File

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-cm  # Name of the ConfigMap, used for reference in Pods or Deployments.
data:
  APP: "frontend"  # Key-value pair that can be used as an environment variable in a Pod.
  ENVIRONMENT: "production"  # Another environment variable for defining the environment.
  index.html: |  # When mounted as a volume, this key creates a file named 'index.html' with the following contents.
    <!DOCTYPE html>
    <html>
    <head><title>Welcome</title></head>
    <body>
      <h1>This page is served by nginx. Welcome to Cloud With VarJosh!!</h1>
    </body>
    </html>
```
The `|` tells YAML:

> “Treat the following lines as a **literal block of text**. Preserve all line breaks and indentation exactly as they appear(formatting).”

In YAML, the `|` symbol is called a **block scalar indicator** — specifically, it's used for **literal block style**.
This is especially useful when you're writing multi-line values, such as **HTML**, **scripts**, or **configuration files** inside a YAML field.

Apply:

```bash
kubectl apply -f frontend-cm.yaml
```

---

### Step 2: Mount ConfigMap Volume in Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy  # Name of the Deployment
spec:
  replicas: 3  # Number of pod replicas
  selector:
    matchLabels:
      app: frontend  # Label selector to identify Pods managed by this Deployment
  template:
    metadata:
      labels:
        app: frontend  # Label to match with the selector above
    spec:
      containers:
      - name: frontend-container  # Name of the container
        image: nginx  # NGINX image to serve web content
        env:
        - name: APP
          valueFrom:
            configMapKeyRef:
              name: frontend-cm  # Name of the ConfigMap to pull the key from
              key: APP  # Key in the ConfigMap whose value will become the value of the env variable APP
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: frontend-cm
              key: ENVIRONMENT  # Key in the ConfigMap whose value becomes the value of ENVIRONMENT variable
        volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html  # Mount point inside the container (default HTML dir for NGINX)
          readOnly: true  # Make the volume read-only
      volumes:
      - name: html-volume
        configMap:
          name: frontend-cm  # The ConfigMap being mounted as a volume
          items:
          - key: index.html  # The key in the ConfigMap to be used as a file
            path: index.html  # The filename that will be created inside the mount path
```

Understand that **ConfigMaps are mounted as directories** in Kubernetes. If you try to mount a ConfigMap at a path that is already a file (like `/usr/share/nginx/html/index.html`), the container will **fail to start**, because Kubernetes **cannot mount a directory over an existing file**.

That’s why we only use `/usr/share/nginx/html` as the `mountPath`, which is a **directory**, not a file.

If you **omit the `items:` section**, like this:

```yaml
volumes:
  - name: html-volume
    configMap:
      name: frontend-cm
```

Then **all the keys** in the ConfigMap (`APP`, `ENVIRONMENT`, `index.html`) will be mounted(copied) as **individual files** inside `/usr/share/nginx/html`.

So inside the container, you’d get:
```
/usr/share/nginx/html/APP
/usr/share/nginx/html/ENVIRONMENT
/usr/share/nginx/html/index.html
```

If you **only want `index.html`** to be mounted (and not `APP`, `ENVIRONMENT`), you should use the `items:` section like this:

```yaml
volumes:
  - name: html-volume
    configMap:
      name: frontend-cm
      items:
        - key: index.html
          path: index.html
```
---

### What if you *do* want to mount the ConfigMap **as a single file**?

You cannot mount a directory on top of an existing file — but you **can mount a specific key** as a file using `subPath`. Here’s how:

```yaml
volumeMounts:
  - name: html-volume                    # References the volume named 'html-volume' defined in the 'volumes' section
    mountPath: /usr/share/nginx/html/index.html  # The exact file path inside the container where the file should be mounted
    subPath: index.html                  # Mount only the 'index.html' key from the ConfigMap as a file (not the whole directory)

```

This tells Kubernetes:  
> “Mount only the file named `index.html` from the ConfigMap into the container at `/usr/share/nginx/html/index.html`.”

This works even if `index.html` already exists in the NGINX image because you're **not replacing a file with a directory**, but a file with a file.

---

**Advantages of Using `subPath`**

- Allows **fine-grained control** over what file is mounted and where.
- Helps you **inject configuration** (like `index.html`) **without overriding entire directories**.
- Enables **mixing static content** from image and dynamic content from ConfigMap.


**Disadvantages of `subPath`**

- The mounted file is **not updated automatically** if the ConfigMap changes (unless the pod is restarted).
- Slightly more complex syntax.
- If the mount path already exists and is a file, mounting may fail without proper use of `subPath`.

---

So, in summary:

- Use `mountPath: /usr/share/nginx/html` to mount a **directory**.
- Use `subPath` to mount a **single file** precisely over a specific path.
- Use `items:` in the volume to **control which keys** from the ConfigMap are mounted.



Apply:

```bash
kubectl apply -f frontend-deploy.yaml
```

* Difference Between items and subPath

| Feature                        | `items`                                                                                                                    | `subPath`                                                                                               |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **Used in**                    | Inside the `volumes:` definition                                                                                           | Inside the `volumeMounts:` definition                                                                   |
| **Purpose**                    | Selects which keys from a ConfigMap (or Secret) to mount, and what filenames they should have inside the mounted directory | Mounts a **single file (or subdirectory)** from a volume into a specific file path inside the container |
| **Mounts**                     | One or more **keys** as **files** inside a directory                                                                       | Exactly **one file or subdirectory** into a specific path                                               |
| **Updates automatically**      | ✅ Yes — reflects ConfigMap changes dynamically                                                                             | ❌ No — not automatically updated; requires pod restart                                                  |
| **Granularity**                | Controls which keys → which files                                                                                          | Controls where a specific file/subdir is mounted                                                        |
| **Common use case**            | Mount only a few specific keys from a ConfigMap                                                                            | Mount a single key as a file over an existing file path                                                 |
| **Defined in YAML**            | Under `volumes.configMap.items:`                                                                                           | Under `containers.volumeMounts[].subPath:`                                                              |
| **Can you use both together?** | ✅ Yes — you can pick a key using `items`, then mount it precisely with `subPath`.                                          |                                                                                                         |


##### Difference Between `items` and `subPath`

| Feature                        | `items`                                                                                                                    | `subPath`                                                                                               |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **Used in**                    | Inside the `volumes:` definition                                                                                           | Inside the `volumeMounts:` definition                                                                   |
| **Purpose**                    | Selects which keys from a ConfigMap (or Secret) to mount, and what filenames they should have inside the mounted directory | Mounts a **single file (or subdirectory)** from a volume into a specific file path inside the container |
| **Mounts**                     | One or more **keys** as **files** inside a directory                                                                       | Exactly **one file or subdirectory** into a specific path                                               |
| **Updates automatically**      | ✅ Yes — reflects ConfigMap changes dynamically                                                                             | ❌ No — not automatically updated; requires pod restart                                                  |
| **Granularity**                | Controls which keys → which files                                                                                          | Controls where a specific file/subdir is mounted                                                        |
| **Common use case**            | Mount only a few specific keys from a ConfigMap                                                                            | Mount a single key as a file over an existing file path                                                 |
| **Defined in YAML**            | Under `volumes.configMap.items:`                                                                                           | Under `containers.volumeMounts[].subPath:`                                                              |
| **Can you use both together?** | ✅ Yes — you can pick a key using `items`, then mount it precisely with `subPath`.                                          |                                                                                                         |

---

##### Example: Using `items`

Suppose your ConfigMap looks like this:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-cm
data:
  APP: frontend
  ENVIRONMENT: production
  index.html: "<h1>Welcome to Frontend</h1>"
```

##### Using `items` to select only `index.html`

```yaml
volumes:
  - name: html-volume
    configMap:
      name: frontend-cm
      items:
        - key: index.html
          path: index.html
```

##### Mount it inside container:

```yaml
volumeMounts:
  - name: html-volume
    mountPath: /usr/share/nginx/html
```

📁 Inside container:

```
/usr/share/nginx/html/index.html
```

✅ `items` lets you choose **which keys** become files in your mount.
✅ `index.html` will update automatically if the ConfigMap changes.

---

##### Example: Using `subPath`

Now, say you want to **replace only one file** inside the container (like the existing NGINX `index.html`) instead of mounting a whole directory.

```yaml
volumeMounts:
  - name: html-volume
    mountPath: /usr/share/nginx/html/index.html
    subPath: index.html
```

This means:

> “Mount the file corresponding to the `index.html` key in the ConfigMap, and place it exactly over `/usr/share/nginx/html/index.html`.”

📁 Inside container:

```
/usr/share/nginx/html/index.html   ← from ConfigMap
```

✅ Useful when:

* You only want **one file**, not the entire ConfigMap directory.
* The target (`/usr/share/nginx/html/index.html`) is already a **file**.

⚠️ Limitation:

* The mounted file **does not auto-refresh** when the ConfigMap changes.
* Pod restart is required to reflect updates.

---

##### Using Both Together

You can combine both for precise control:

```yaml
volumes:
  - name: html-volume
    configMap:
      name: frontend-cm
      items:
        - key: index.html
          path: index.html

volumeMounts:
  - name: html-volume
    mountPath: /usr/share/nginx/html/index.html
    subPath: index.html
```

This:

* Uses `items` to include only the `index.html` key.
* Uses `subPath` to mount it specifically as `/usr/share/nginx/html/index.html`.

---

##### Visual Comparison

```
ConfigMap: frontend-cm
├── APP
├── ENVIRONMENT
└── index.html
```

##### Using `items`

```
Mount → /usr/share/nginx/html/
│
├── index.html     ← Mounted (from ConfigMap)
```

###### Using `subPath`

```
Mount → /usr/share/nginx/html/index.html
(index.html file directly replaces existing one)
```

---

##### When to Use What

| Situation                                                                               | Recommended Approach               |
| --------------------------------------------------------------------------------------- | ---------------------------------- |
| You want **all** ConfigMap keys as files                                                | Mount volume directly (no `items`) |
| You want **only specific keys**                                                         | Use `items`                        |
| You want to **replace a single existing file** (e.g., `/etc/nginx/conf.d/default.conf`) | Use `subPath`                      |
| You need ConfigMap updates to auto-refresh                                              | Use `items` (don’t use `subPath`)  |
| You mix static + dynamic content                                                        | Use both (`items` + `subPath`)     |


#### Permissions
* When you mount a Secret as a volume inside a Pod, each key inside the Secret becomes a file.

* By default, those files get POSIX permissions 0644 (owner read/write, group read, others read).

* You can customize this with the defaultMode field (e.g., 0400 = read-only for owner).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
  - name: mypod
    image: redis
    volumeMounts:
    - name: foo
      mountPath: "/etc/foo"
  volumes:
  - name: foo
    secret:
      secretName: mysecret
      defaultMode: 0400
```
* The defaultMode: 0400 means:
  * All files (keys from the Secret) under /etc/foo will have permissions set to readable only by the owner (root).
  * So, when the container runs, /etc/foo/<keyname> files will each have mode `-r--------`.

* You can override permissions per key if you want specific files to have different permissions. Example:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
  - name: mypod
    image: redis
    volumeMounts:
    - name: foo
      mountPath: "/etc/foo"
  volumes:
  - name: foo
    secret:
      secretName: mysecret
      items:
      - key: password
        path: my-password
        mode: 0600
```
* This sets /etc/foo/my-password to 0600, even if defaultMode was different.

* **JSON caution**:
  * JSON doesn’t support octal literals like 0400.
  * In JSON, 0400 would be interpreted as decimal 400.
  * To correctly specify file modes in JSON, you must use decimal equivalents:
    * Octal 0400 → Decimal 256
    * Octal 0600 → Decimal 384
    * Octal 0644 → Decimal 420
```json
"secret": {
  "secretName": "mysecret",
  "defaultMode": 256
}
```

---

## **Step 3: Expose the Deployment using a NodePort Service**

We’ll now expose our NGINX-based frontend deployment using a **NodePort** service. This allows access to the application from outside the cluster by targeting any worker node’s IP and the assigned NodePort.

### NodePort Service Manifest

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc  # Name of the service
spec:
  type: NodePort       # Exposes the service on a static port on each node
  selector:
    app: frontend      # Targets pods with this label
  ports:
    - protocol: TCP
      port: 80         # Port exposed inside the cluster (ClusterIP)
      targetPort: 80   # Port the container is listening on
      nodePort: 31000  # External port accessible on the node (must be between 30000–32767)
```

Apply the service:

```bash
kubectl apply -f frontend-svc.yaml
```
---

## **Verification**

#### 1. Get the Pod name

```bash
kubectl get pods -l app=frontend
```

#### 2. Verify the `index.html` content inside the container

```bash
kubectl exec -it <pod-name> -- cat /usr/share/nginx/html/index.html
```

**Expected Output:**

```html
<!DOCTYPE html>
<html>
<head><title>Welcome</title></head>
<body>
  <h1>This page is served by nginx. Welcome to Cloud With VarJosh!!</h1>
</body>
</html>
```

---

#### 3. Access the Application via NodePort

You can access the application using:

```bash
http://<Node-IP>:31000
```

Or with `curl`:

```bash
curl http://<Node-IP>:31000
```

> Replace `<Node-IP>` with the IP address of any node in your cluster (typically a worker node).

---

#### 4. **If You're Using KIND (Kubernetes in Docker)**

If you've been following this course using a **KIND cluster**, the worker nodes are running inside a Docker container. In this case, KIND maps NodePorts to your host (Mac/Windows/Linux) via localhost.

**For more details, refer to the Day 12 GitHub notes:**  
[Setting up a KIND Cluster with NodePort Service](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025/tree/main/Day%2012#setting-up-a-kind-cluster-with-nodeport-service)

So you can directly access the app using:

```bash
http://localhost:31000
```

Or:

```bash
curl http://localhost:31000
```

This will display the content served by NGINX from the ConfigMap-mounted `index.html`.

--- 


### **Best Practices for ConfigMap**

- Avoid storing sensitive data in ConfigMaps.
- Mount only the necessary keys using `items` to limit volume content.
- Use version control tools (e.g., Kustomize, Helm) to manage changes.
- Combine ConfigMaps with `subPath` if you want to mount specific files.

---

## Kubernetes Secrets
### **Why Do We Need Secrets in Kubernetes?**

In production environments, applications often require access to sensitive data such as:

- **Database credentials:** Used by applications to authenticate securely with backend databases.
- **API tokens:** Serve as secure keys to authorize and access APIs or third-party services.
- **SSH private keys:** Enable secure, encrypted access to remote systems over SSH.
- **TLS certificates:** Provide encryption and identity verification for secure network communication (e.g., HTTPS).

Storing these directly in your container image or Kubernetes manifests as plain text is insecure. **Kubernetes Secrets** provide a way to manage this data securely.

---

### **What is a Kubernetes Secret?**

A **Secret** is a Kubernetes object used to store and manage sensitive information. Secrets are base64-encoded and can be made more secure by:

- Enabling encryption at rest
- Limiting RBAC access to Secrets
- Using external secret managers like HashiCorp Vault, AWS Secrets Manager, or Sealed Secrets

Accessible to Pods via:
  1. **Environment variables**
  2. **Mounted volumes (as files)**
  3. **Command-line arguments** (less common)

> Note: By default, Kubernetes stores secrets unencrypted in `etcd`. It is recommended to enable encryption at rest for better security.

![](/1-CKA-Certification-Course-2025/images/image5.png)
---

### **Important Distinction: Encoding vs. Encryption**

It's crucial to understand that **Kubernetes Secrets use base64 *encoding*, not encryption**.  
This means the data is **obfuscated but not secured**. Anyone who gains access to the Secret object can **easily decode** it.

**Why Use Encoding (e.g., base64)?**

Encoding is useful when you want to **hide the data from casual observation**, such as:

- Preventing someone looking over your shoulder from instantly seeing a password.
- Making binary data safe to transmit in systems that expect text.

However, **encoding is not encryption**. It's **not secure** by itself.  
> Anyone who has access to your encoded data can easily decode it.

For example, base64 is **reversible** using a simple decoding command.  
If you need to **protect sensitive data**, you should use **encryption** or a Kubernetes **Secret**, which at least provides better handling and access controls.

We'll see how to **encode** and **decode** in the demo section.

---

### **Encoding vs. Encryption**

| Feature         | Encoding                        | Encryption                           |
|----------------|----------------------------------|--------------------------------------|
| **Purpose**     | Data formatting for safe transport | Data protection and confidentiality |
| **Reversible**  | Yes (easily reversible)          | Yes (only with the correct key)      |
| **Security**    | Not secure                       | Secure                                |
| **Use Case**    | Data transmission/storage compatibility | Protect sensitive data (passwords, tokens) |
| **Example**     | Base64, URL encoding             | AES, RSA, TLS                        |
| **Tool Needed to Decode** | None (any base64 tool)         | Requires decryption key              |

---

> **Note:** If you need to store sensitive data securely, consider enabling **encryption at rest** for Secrets in Kubernetes and restrict access using RBAC.

---

### **Demo 1: Injecting Secrets into a Pod**

We’ll enhance the existing `frontend-deploy` and `frontend-svc` resources by securely injecting database credentials using a Kubernetes Secret.

For this demo, we’ll build on the `frontend-deploy` configuration introduced in **Day 12** of this course. If you'd like a deeper understanding of **Kubernetes Services**, feel free to explore the following resources:

- [Day 12 GitHub Notes](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025/tree/main/Day%2012)  
- [Day 12 YouTube Video](https://www.youtube.com/watch?v=92NB8oQBtnc)

These resources provide clear examples and explanations of how Kubernetes Services work in real-world deployments.

---

### **Step 1: Create the Secret**

Create a Secret manifest `frontend-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret  # Declares the resource type as a Secret.
metadata:
  name: frontend-secret  # Unique name for this Secret object.
type: Opaque  # 'Opaque' means this Secret contains user-defined (arbitrary) key-value pairs.

data:
  DB_USER: ZnJvbnRlbmR1c2Vy  # Base64-encoded value of 'frontenduser'
  DB_PASSWORD: ZnJvbnRlbmRwYXNz  # Base64-encoded value of 'frontendpass'

  # NOTE:
  # Values under the 'data:' section must be base64-encoded.
  # These can be referenced by Pods to inject as environment variables or mounted as files.
```
* “User-defined” or “arbitrary” means you choose the keys and values yourself — they’re not pre-defined or required by the system.

To generate the base64-encoded values:

```bash
echo -n 'frontenduser' | base64      # ZnJvbnRlbmR1c2Vy
echo -n 'frontendpass' | base64      # ZnJvbnRlbmRwYXNz
```

To decode the values on a Linux system:

```bash
echo 'ZnJvbnRlbmR1c2Vy' | base64 --decode   # frontenduser
echo 'ZnJvbnRlbmRwYXNz' | base64 --decode   # frontendpass
```

> **Note:** The `-n` flag with `echo` ensures no trailing newline is added before encoding.

Apply the Secret:

```bash
kubectl apply -f frontend-secret.yaml

controlplane:~$ kubectl get secret
NAME              TYPE     DATA   AGE
frontend-secret   Opaque   2      5s
```

---

### **Step 2: Update the Deployment to Use the Secret**

Here’s the updated deployment manifest (`frontend-deploy.yaml`) using the `frontend-secret` Secret as environment variables:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy  # Name of the Deployment
spec:
  replicas: 1  # Run a single replica of the frontend Pod
  selector:
    matchLabels:
      app: frontend  # This selector ensures the Deployment manages only Pods with this label
  template:
    metadata:
      labels:
        app: frontend  # Label added to the Pod; matches the selector above
    spec:
      containers:
        - name: frontend-container  # Name of the container running inside the Pod
          image: nginx  # Using official NGINX image
          env:
            - name: DB_USER  # Environment variable DB_USER inside the container
              valueFrom:
                secretKeyRef:
                  name: frontend-secret  # Name of the Secret resource
                  key: DB_USER  # Key in the Secret to pull the value from
            - name: DB_PASSWORD  # Environment variable DB_PASSWORD inside the container
              valueFrom:
                secretKeyRef:
                  name: frontend-secret  # Same Secret object
                  key: DB_PASSWORD  # Another key from the Secret object

  # The environment variables DB_USER and DB_PASSWORD will be injected into the container at runtime.
  # Kubernetes will automatically base64-decode the values from the Secret and inject them as plain-text.
  # That means inside the container, these environment variables will appear as plain-text,
  # even though they are stored in base64-encoded format in the Kubernetes Secret object.

```

Apply the deployment:

```bash
kubectl apply -f frontend-deploy.yaml
```

---

### **Step 3: Verify Secret Injection**

1. List the running Pods:

```bash
kubectl get pods -l app=frontend
```

2. Exec into one of the Pods:

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

3. Print the environment variables:

```bash
echo $DB_USER       # Expected output: frontenduser
echo $DB_PASSWORD   # Expected output: frontendpass
```

---

### **Alternative: Mount Secret as Files**

If you prefer to mount secrets as files (instead of environment variables), here’s how:

#### Update container spec:

Certainly! Here's your `volumeMounts` section with clear and concise inline comments:

```yaml
        volumeMounts:
          - name: secret-volume               # Refers to the volume named 'secret-volume' defined in the 'volumes' section
            mountPath: /etc/secrets           # Directory inside the container where the secret files will be mounted
            readOnly: true                    # Ensures the mounted volume is read-only to prevent modifications from within the container
```
**Additional Notes:**

- Each key in the Secret will be mounted as a **separate file** under `/etc/secrets`.
- For example, if your Secret has `DB_USER` and `DB_PASSWORD`, you’ll find:
  ```bash
  /etc/secrets/DB_USER
  /etc/secrets/DB_PASSWORD
  ```
- These files will contain the **decoded plain-text values** from the Secret.


#### Add volume to spec:

Certainly! Here's the corresponding `volumes:` section with detailed inline comments to pair with the `volumeMounts` section above:

```yaml
      volumes:
        - name: secret-volume                # The volume name referenced in volumeMounts
          secret:
            secretName: frontend-secret     # The name of the Secret object from which to pull data

            # Optional: you could use 'items' here to mount only specific keys
            # For example:
            # items:
            #   - key: DB_USER
            #     path: db-user.txt
            #   - key: DB_PASSWORD
            #     path: db-password.txt

            # Without 'items', all keys from the Secret will be mounted as individual files
            # in the mountPath directory (e.g., /etc/secrets/DB_USER, /etc/secrets/DB_PASSWORD)
```

---

### **Best Practices for Using Kubernetes Secrets**

- Avoid storing secrets in Git repositories.
- Use `kubectl create secret` or Helm to avoid manually encoding data.
- Enable encryption at rest in `etcd`.
- Use Role-Based Access Control (RBAC) to restrict access to secrets.
- Use external secret managers for enhanced security and auditability.
- Consider using `subPath` when mounting specific keys from a Secret as individual files.

---

### **Understanding Dynamic Updates with ConfigMaps and Secrets**

- Environment variables defined via `env.valueFrom.configMapKeyRef` or `secretKeyRef` are **evaluated only once** when the pod starts.
- Updating the underlying ConfigMap or Secret **does not affect** the values already injected as environment variables in a running container.
- ConfigMaps or Secrets mounted as **volumes** (without `subPath`) **do reflect updates dynamically** inside the container.
- Kubernetes handles dynamic updates using **symlinks** to new file versions, but the application must **re-read the files** to detect changes.
- When mounting individual keys using `subPath`, the file is **copied**, not symlinked, so updates to the ConfigMap or Secret **will not propagate**.
- To enable live updates without restarting pods, prefer **volume mounts without `subPath`** and ensure the application supports **hot reloading** or use a **config-reloader**.

---

## **Conclusion**

In this module, you learned how to effectively use **Kubernetes ConfigMaps and Secrets** to decouple configuration and sensitive data from your application code. You explored how to inject this data into pods as environment variables and volume-mounted files, and understood the limitations of dynamic updates when using different mounting strategies.

You also learned how Secrets differ from ConfigMaps in terms of intended usage and security posture, and reviewed practical examples of how to securely manage credentials inside your Kubernetes cluster. By following best practices—such as enabling encryption at rest, restricting RBAC access, and avoiding hardcoded credentials—you can build more secure and maintainable Kubernetes-native applications.

As you move forward in your DevOps journey, mastering ConfigMaps and Secrets will become an essential part of deploying applications reliably and securely in any Kubernetes environment.

---

## **References**

- [ConfigMaps Overview](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets Overview](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Managing Secrets Using kubectl](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/)
- [Mounting ConfigMaps as Volumes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Using SubPath to Mount Individual Files](https://kubernetes.io/docs/concepts/storage/volumes/#using-subpath)

---
