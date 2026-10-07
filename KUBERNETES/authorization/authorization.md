## **Authorization in Kubernetes**

* **Authentication** verifies *who* you are.
* **Authorization** determines *what* you are allowed to do.

Once a user, group or service account (SA) is **authenticated**, Kubernetes must determine **whether** that identity is **allowed to perform the requested action**. This process is called **authorization**.

Authorization answers questions like:

* Can this user **read** pods in the `default` namespace?
* Is this service account allowed to **delete** a deployment in `production`?
* Can this user create **roles** at the cluster level?

Authorization decisions consider not only the **user** but also the **groups** they belong to. In Kubernetes, a user or service account can be a member of one or more **groups**, and permissions may be granted based on either the individual identity or their group membership.

> You’ll learn more about **Service Accounts** and how they interact with authorization in an upcoming lecture of this course.

---

## **High-Level Flow of Authorization**

When a request reaches the API server:

1. **Authentication**: Who are you?
2. **Authorization**: Are you allowed to do what you're asking?
3. **Admission Control**: Should this request be allowed under current policies and configurations? This will be covered in upcoming lectures.

If **authorization** fails, the request is rejected with a `403 Forbidden`.

---

## **Authorization is Context-Aware**

A typical Kubernetes authorization decision considers:

* **User identity** (from authentication)
* **Requested verb** (`get`, `create`, `delete`, `patch`, etc.)
* **Resource type** (`pods`, `deployments`, `services`, etc.)
* **Resource name** (optional)
* **Namespace** (if namespaced)
* **API group**
* **Non-resource URLs** (for endpoints like `/metrics`, `/healthz`)

---

## **Types of Authorization Modes in Kubernetes**

Kubernetes supports **multiple pluggable authorizers**, which are evaluated in order. The first one to make a definitive decision (allow/deny) halts the chain.

Here are the most common ones:

### 1. **[RBAC (Role-Based Access Control)](/KUBERNETES/authorization/rbac/rbac.md)**
### 2. **[ABAC (Attribute-Based Access Control)](/KUBERNETES/authorization/abac/abac.md)**
### 2. **[Webhook Authorization](/KUBERNETES/authorization/abac/abac.md)**