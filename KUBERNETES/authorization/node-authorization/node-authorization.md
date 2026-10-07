### **Node Authorization**

**Purpose:**
Node Authorization is a specialized authorization mode built into the Kubernetes API server to **restrict what kubelets (the node agents) can do**. It ensures that each kubelet can only access or modify resources that are specifically related to the node it runs on.

**How It Works:**
In our TLS lecture (Part 3), we saw that each kubelet authenticates itself to the API server using a **bootstrap token** or client certificates. However, authentication only verifies identity — it doesn’t define permissions. That’s where Node Authorization applies.

Node Authorization enforces that the kubelet on, for example, **node1** can only:

* Read pod specs, Secrets, ConfigMaps, volume mounts, and other resources related to the pods **scheduled on node1**.
* Update status or metadata of these same node-specific resources.

It **cannot** access resources assigned to any other node, such as pods running on **node2**.

The API server uses the kubelet’s node identity (via its client certificate) to enforce these scoped permissions automatically.

**Why It Matters:**
This mode confines the kubelet’s privileges strictly to its own node’s workload, improving cluster security by:
* Preventing accidental or malicious access to other nodes’ pods or secrets.
* Minimizing the potential impact if a node or kubelet is compromised.

**Activation and Usage:**
Node Authorization is **enabled automatically by the API server** for kubelet requests and does not require any manual configuration of Roles or RoleBindings.

---

### Key Points:

| Step                   | Explanation                                            |
| ---------------------- | ------------------------------------------------------ |
| **Bootstrap token**    | Kubelet authenticates to the API server                |
| **Node Authorization** | Kubelet can only read or modify resources for its node |

This built-in authorization method ensures secure, node-scoped access control, keeping each node’s workload isolated in terms of API permissions.