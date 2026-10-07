## Authentication in Kubernetes
Authentication is the **first step** in the security flow of a Kubernetes cluster. Every request to the API server must prove its identity before being authorized to do anything.

Kubernetes does **not maintain an internal user database**, so you cannot manually create user accounts like you would on a Linux system. Instead, **human users are managed externally** — commonly using TLS certificates, Identity provider tokens (OIDC), or authentication proxies.

In contrast, Kubernetes **does support creation of Service Accounts**, specifically designed for non-human access **from inside and outside the cluster**.

Service account allow internal and external services to interact with the API-Server.

Kubernetes supports multiple authentication methods. Below are the most common ones, along with their real-world implications and usage.

![Alt text](/images/37a.png)

- Static Password File
- Static Token
- Service Account
- Certificates
- External Identity Providers

---

### Understanding Who Interacts with a Kubernetes Cluster

![Alt text](/images/37b.png)

There are broadly two types of entities that interact with a Kubernetes cluster:

1. **Humans** – such as administrators, developers, and SREs, typically using `kubectl`, the Kubernetes Dashboard, or client tools.
2. **Non-human agents** – Automated systems that interact with the cluster either from **outside** or from **within**.
  * Allowing third-party monitoring tools to access Kubernetes data.
  * External applications to access kubernetes resources.
  * Prometheus needs read access to cluster API to get information from metrics server, read pods, etc.
  * When you deploy Prometheus, you add cluster read permissions to the default service account where the Prometheus pods are deployed. This way, Prometheus pods get read access to cluster resources.

- [Service account](/KUBERNETES/authentication/token-based-authentication/service-account/service-account.md)