### Kubernetes Context
**Kubernetes contexts** allow users to easily manage multiple clusters and namespaces by storing cluster, user, and namespace information in the `kubeconfig` file. Each context defines a combination of a cluster, a user, and a namespace, making it simple for users like `Seema` to switch between clusters and namespaces seamlessly without manually changing the configuration each time.

![Alt text](/images/31-10.png)

## Scenario:

Seema, the user, wants to access three different Kubernetes clusters from her laptop. Let's assume these clusters are:

1. **dev-cluster** (for development)
2. **staging-cluster** (for staging)
3. **prod-cluster** (for production)

Seema will need to interact with these clusters frequently. Using Kubernetes contexts, she can set up and switch between these clusters easily.

## How Kubernetes Contexts Work:

### 1. Configuring Contexts:

In the `kubeconfig` file, each cluster, user, and namespace combination is stored as a context. So, Seema can have three different contexts, one for each cluster. The contexts will contain:

* **Cluster details**: API server URL, certificate authority, etc.
* **User details**: Authentication method (e.g., username/password, token, certificate).
* **Namespace details**: The default namespace to work in for the context (though the namespace can be overridden on a per-command basis).

### 2. Switching Between Contexts:

With Kubernetes contexts configured, Seema can easily switch between them. If she needs to work on **dev-cluster**, she can switch to the `dev-context`. Similarly, for **staging-cluster**, she switches to `staging-context`, and for **prod-cluster**, the `prod-context`.

A **Kubernetes namespace** is a virtual cluster within a physical cluster that provides logical segregation for resources. This allows multiple environments like dev, staging, and prod to coexist on the same cluster without interference.

We now use naming like `app1-dev-ns`, `app1-staging-ns`, and `app1-prod-ns` to logically group and isolate resources of `app1` across environments.

For example, `app1-dev-ns` in dev-cluster keeps all resources related to `app1`'s development isolated from production resources in `app1-prod-ns` on prod-cluster.