### **Webhook Authorization**

With **webhooks**, you essentially **outsource the authorization decision** from the Kubernetes API server to an **external service**. This external service receives each request’s details and decides whether to **allow or deny** it.

The API server sends a **JSON payload** describing the request (user, action, resource, namespace, etc.) to the external endpoint. The endpoint evaluates the request and responds with a decision.

**Common tools used with Webhook authorization:**

* **OPA (Open Policy Agent)** – General-purpose policy engine
* **Gatekeeper** – Kubernetes-native policy enforcement using OPA + CRDs
* **Kyverno** – Policy engine built specifically for Kubernetes
* **Custom in-house authorization services** – For organizations with unique compliance or audit needs

---

#### **Why Use Webhooks?**

Webhook authorization is valuable when:

* You need **fine-grained control** over access decisions that go beyond what RBAC allows
* Policies depend on **dynamic attributes**, such as labels, annotations, request time, or even external systems
* You want to enforce **business-specific rules**, such as:
  * “Only the security team can delete Pods in `production`”
  * “Developers can only scale Deployments within 2–5 replicas”
  * “CI/CD pipelines can only deploy images signed by our internal registry”

> **Note:** You must configure the API server with the `--authorization-mode=Webhook` flag and provide a `--authorization-webhook-config-file` that defines the endpoint and connection details.

> Webhook authorization offers **maximum flexibility** but adds **external dependencies** and potential latency. It's typically used in **large, security-conscious environments** with strict compliance requirements.

> *Note:* Kubernetes also supports **validating** and **mutating** admission webhooks, which are different mechanisms used during object creation or update for enforcing policies or making changes. These will be covered later in the course when discussing **admission controllers**.

---

### **Combining RBAC and Webhook Authorization**

**RBAC** is great for defining **what actions** a user, group or service account can perform—such as allowing Seema to create Pods. However, it cannot enforce **how** those actions are performed.

For example:
Seema is allowed to create Pods (**RBAC**), but **only if** the container image comes from `registry.pinkcompany.com`.
RBAC can’t enforce this kind of condition because it doesn't inspect the request content, like the Pod spec.

This is where **Webhook authorization** becomes essential. A **Webhook authorizer** lets the API server **delegate fine-grained, context-aware decisions** to an external service. It can inspect the **full request**, including the object spec, and enforce **custom policies**—like verifying image sources, naming patterns, or requiring external approvals.

Technically, this scenario **can be handled using just a Webhook**:
When Seema attempts to create a Pod, the API server sends the request to the Webhook. The Webhook inspects the request and either returns `allow` or `deny`. In this setup, the Webhook performs **both authorization and policy enforcement**.

However, in production environments, it’s **common to combine RBAC and Webhook**:

* **RBAC acts as the first gate**, granting access based on roles and permissions.
* **Webhook provides a second layer**, enforcing rules RBAC can’t express—like conditional logic or external validations.

This layered approach keeps **RBAC rules simple and maintainable**, while offloading complex or evolving policies to the Webhook.

> 🔹 **Order matters**
> When multiple authorization modes are configured, the API server evaluates them **in order**. The first mode to return `allow` or `deny` **ends the evaluation**.
>
> To ensure the Webhook always gets a chance to evaluate the request first, configure the API server like this:

```bash
--authorization-mode=Webhook,RBAC
```

This guarantees:

* **Webhook evaluates every request first**.
* If it returns `"no opinion"`, the request **falls through to RBAC** for standard permission checks.

---

## Authorization Flow When Node, Webhook Authorizer, and RBAC Are Used Together

**Requirements:**

* Seema must have **permission** to create Pods.
* The Pod's image must come from **`registry.pinkcompany.com`**.

---

### Clarification: OPA Can Be Used in Two Ways

**OPA** (Open Policy Agent) can integrate with Kubernetes in two different roles:

1. **Webhook Authorizer** – Participates in the **authorization phase**. It can allow or deny requests based on **request metadata only** like user, verb, namespace — **just like RBAC**, but with more flexibility:

   * **Time-aware access**: Deny deletes during business hours
   * **Network-aware access**: Allow requests only from specific CIDRs
   * **Custom identity checks**: Integrate with external systems (HR, LDAP)

   > It cannot see the Pod spec or image field.

2. **Admission Controller (Validating Webhook)** – Participates in the **admission phase**, where it can inspect and validate the **full object** like container images, labels, security settings, etc.

✅ The image registry validation (e.g., checking for `registry.pinkcompany.com`) is performed by OPA acting as a **Validating Admission Controller**, not as a Webhook Authorizer.

We’ll cover custom admission controllers in **Day 38** in more depth.

---

### Scenario 1: Using Node + Webhook Authorizer Only

![Alt text](/images/35a.png)

API server configuration:

```bash
--authorization-mode=Node,Webhook
```

#### 🔁 Flow (Seema creates a Pod):

1. Seema sends a request to create a Pod.

2. **Node Authorizer** is checked first.

   * Since it's not a kubelet-originated request, Node returns **"no opinion"**.

3. The **Webhook Authorizer** (OPA) is evaluated.

   * It checks Seema’s identity and request metadata.

   * It may enforce policies like:

     * "Only allow requests during off-hours"
     * "Allow only users in the `devs` group"

   * **It cannot** inspect the Pod spec to check image source.

4. If Webhook returns:

   * ✅ `allow` → request proceeds to **admission phase**
   * ❌ `deny` → request is rejected

5. If allowed, **OPA (as Admission Controller)** then validates:

   * Is the Pod image from `registry.pinkcompany.com`?
   * If yes → ✅ request proceeds
   * If not → ❌ request is rejected

> 🔄 OPA is used in **both phases**, but for different purposes:
>
> * **Authorization**: Checks user-level access (via webhook authorizer)
> * **Admission**: Enforces deep policy (via admission controller)

---

### Scenario 2: Node + Webhook + RBAC (Layered)

![Alt text](/images/35b.png)

API server configuration:

```bash
--authorization-mode=Node,Webhook,RBAC
```

#### 🧭 Roles of Each Mode

| Mode    | Role                                                 |
| ------- | ---------------------------------------------------- |
| Node    | Handles kubelet-only requests                        |
| Webhook | Custom logic based on request metadata               |
| RBAC    | Standard user/group/serviceaccount permission checks |

OPA runs as:

* **Webhook Authorizer** → for request-based policies (time, group, network)
* **Admission Controller** → for object-based policies (image, labels, etc.)

#### 🔁 Flow:

1. Seema sends a request to create a Pod.
2. **Node Authorizer** returns `"no opinion"` (not a kubelet request).
3. **Webhook Authorizer** (OPA):

   * Checks time-based or identity policies.
   * If all good → returns `"no opinion"` → continue.
   * If policy violated → returns `"deny"` → request blocked.
4. **RBAC Authorizer**:

   * Checks if Seema has permission to create Pods.
   * If not → ❌ rejected.
   * If yes → ✅ passed to **admission phase**.
5. **OPA Admission Controller** now inspects the Pod:

   * It checks: is the image from `registry.pinkcompany.com`?
   * If yes → Pod is admitted.
   * If not → request is denied.

---

### ✅ Summary Table

| Phase         | Who Handles It                | What Is Checked                                          |
| ------------- | ----------------------------- | -------------------------------------------------------- |
| Authorization | Node / Webhook / RBAC         | Request metadata (user, verb, resource, group, etc.)     |
| Admission     | OPA (as admission controller) | Full object spec (e.g., Pod images, labels, annotations) |

> 💡 In production, this layered approach allows Kubernetes to:
>
> * Use **RBAC** for basic permissions.
> * Use **OPA webhook authorizer** for request-level logic.
> * Use **OPA admission controller** for deep object inspection (like image validation).

---

## **Conclusion**

Today, we explored the **Kubernetes API** as the core RESTful engine driving every action in your cluster. We covered its key **endpoints**, the difference between **core and named API groups**, and how `kubectl` translates your commands into secure API calls. You also learned how the `apiVersion` in manifests ties directly to these API groups, and that some endpoints remain open for essential health checks even without authentication.

Most importantly, we clarified **Kubernetes authorization**: after authentication confirms *who you are*, authorization decides *what you’re allowed to do*—taking into account the user, action, and resources involved. We examined the main **authorization modes**—from the widely used **RBAC**, to **ABAC**, **Webhook**, **Node authorization**, and the basic **AlwaysAllow/AlwaysDeny** modes. A crucial insight is how Kubernetes evaluates these modes **in order**, stopping at the first definitive “allow” or “deny” decision, which makes the order set in `--authorization-mode` critical for your cluster’s security.

With this foundational understanding of the API and layered authorization, you’re now well-prepared to troubleshoot access issues, design effective policies, and confidently manage secure Kubernetes environments—essential skills for any Kubernetes administrator.