## **How to Check and Change the Authorization Mode in Kubernetes**

### 1. Authorization Happens in the API Server

As we know, **the Kubernetes API server is responsible for both authentication and authorization**. While authentication confirms the identity of the user or service, authorization decides whether that identity is allowed to perform a requested action.

* When **webhook authorization** is used, the API server outsources part of the authorization decision to an external service.
* Regardless, the **authorization mode(s) are defined and configured in the API server itself**.

---

### 2. Where to Find the API Server Configuration

* On **most Kubernetes clusters created with kubeadm, KIND (which uses kubeadm under the hood), or minikube**, the control plane components (including the API server) run as **static pods** managed by the kubelet. This ensures consistent and resilient management. While **kops** can also run components as static pods, it may use alternatives like systemd units depending on the setup.


* The static pod manifests are typically located in:

  ```
  /etc/kubernetes/manifests/kube-apiserver.yaml
  ```

* You can **inspect this file to check the API server command line flags**, including `--authorization-mode`.

> **Note:**
> Managed Kubernetes services like **EKS, AKS, and GKE** **abstract away the control plane from users**. You don’t have access to the control plane nodes or the configuration of components like the API server. This means you cannot directly view or modify the authorization modes—they are fully managed by the provider.
> Is managed k8s service is keep control plane in HA env and all component cna be run as pod, vm etc

---

### 3. Multiple Authorization Modes Can Be Used Together

* The API server supports specifying **multiple authorization modes at once**, separated by commas.
* The modes are **evaluated sequentially** in the order they are listed.
* As soon as one mode **allows or denies** the request, the evaluation stops — later modes are **not evaluated**.

---

#### How Authorization Modes Work Together

When Kubernetes is configured with multiple authorization modes, such as:

```yaml
--authorization-mode=Node,RBAC,Webhook
```

the API server evaluates them **in the order specified**.

---

#### Core Decision Logic

Each authorization mode can respond in **one of three ways**:

| Decision       | Meaning                                                            |
| -------------- | ------------------------------------------------------------------ |
| **Allow**      | The request is **authorized** — no further checks are performed    |
| **Deny**       | The request is **denied** — no further checks are performed        |
| **No Opinion** | The mode doesn't apply — evaluation continues to the **next mode** |

> 🚨 The **first definitive answer** (either "allow" or "deny") stops the evaluation process.

---

#### Example Flow: User Seema Sends a Request

Suppose a user named **Seema** tries to perform an action and Kubernetes is running:

```yaml
--authorization-mode=Node,RBAC,Webhook
```

Here's how her request is processed:

1. **Node Authorization**
   * Designed for kubelet requests.
   * Likely returns **“no opinion”** for Seema.
     → Evaluation moves to RBAC.

2. **RBAC Authorization**
   * If Seema has the necessary permissions: returns **"allow"** → request is authorized.
   * If explicitly blocked: returns **"deny"** → request is denied.
   * If irrelevant: returns **"no opinion"** → evaluation moves to Webhook.

3. **Webhook Authorization**
   * Called **only if both Node and RBAC returned "no opinion"**.
   * Delegates the final decision to an external system.

---

### 4. How to Change Authorization Modes

* To **change the authorization mode**, you edit the API server manifest (`/etc/kubernetes/manifests/kube-apiserver.yaml`) and modify the `--authorization-mode` flag.
* After saving changes, because this is a static pod, **the kubelet automatically restarts the API server with the new configuration**.
* Remember, **changing authorization modes affects cluster security**, so only modify this if you understand the implications.

---

### 5. **Special Authorization Modes: AlwaysAllow and AlwaysDeny**

* Kubernetes also supports **`AlwaysAllow`** and **`AlwaysDeny`** as simple authorization modes.
* These are **primarily used for testing, development, or troubleshooting**.
* **`AlwaysAllow`** grants all requests without any checks.
* **`AlwaysDeny`** rejects all requests outright.
* **Not recommended for production environments** due to obvious security risks.
* You might occasionally see these modes listed in `--authorization-mode` during local test clusters or demos.
* Like other modes, they can be combined in a list of modes, but be cautious as `AlwaysAllow` will effectively bypass other checks.

---

### Key Points:

| Step                   | What to do                                                                                   |
| ---------------------- | -------------------------------------------------------------------------------------------- |
| Find API server config | Check `/etc/kubernetes/manifests/kube-apiserver.yaml` on control plane nodes (if accessible) |
| Identify auth modes    | Look for `--authorization-mode` flag in the API server manifest                              |
| Understand mode order  | Modes evaluated in sequence, first decisive allow/deny stops further checks                  |
| Modify modes           | Edit manifest file, save, and let kubelet restart the API server                             |
| Managed services note  | Authorization mode config hidden in managed services like EKS, AKS, GKE                      |
