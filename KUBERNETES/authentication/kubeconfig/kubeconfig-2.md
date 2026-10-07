Here’s a clear explanation in English about **client certificate configuration in Kubernetes kubeconfig files**, covering both **file‑based** and **embedded** approaches, along with practical examples.

---

## Overview

In a Kubernetes `kubeconfig` file, you can authenticate a user to the cluster using **TLS client certificates**. There are two ways to specify these certificates:

1. **File paths** – reference external `.crt` and `.key` files.
2. **Embedded data** – encode the PEM content as **Base64** directly into the config.

Both methods work for the **client certificate**, its **private key**, and the **cluster CA certificate** (for server verification).

---

## Option 1 – Using File Paths

This is the simplest way: you just point to the certificate files.

```yaml
apiVersion: v1
kind: Config
users:
- name: my-user
  user:
    client-certificate: /path/to/client.crt   # PEM file
    client-key: /path/to/client.key           # PEM file
clusters:
- name: my-cluster
  cluster:
    certificate-authority: /path/to/ca.crt    # CA file
    server: https://k8s.example.com:6443
contexts:
- context:
    cluster: my-cluster
    user: my-user
  name: my-context
current-context: my-context
```

| Field | Purpose |
|-------|---------|
| `client-certificate` | Path to the user’s TLS certificate (PEM). |
| `client-key` | Path to the user’s private key (PEM). |
| `certificate-authority` | Path to the cluster CA certificate (used to verify the API server). |

**Pros** – certificates can be updated independently; the kubeconfig stays small.  
**Cons** – the kubeconfig is not self‑contained; you must also distribute the certificate files.

---

## Option 2 – Embedding Certificate Data

Here the certificate content is **Base64‑encoded** and placed directly inside the `kubeconfig`. This makes the file fully portable.

```yaml
apiVersion: v1
kind: Config
users:
- name: my-user
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSU...   # Base64
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUl...   # Base64
clusters:
- name: my-cluster
  cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSU... # Base64
    server: https://k8s.example.com:6443
contexts:
- context:
    cluster: my-cluster
    user: my-user
  name: my-context
current-context: my-context
```

| Field | Purpose |
|-------|---------|
| `client-certificate-data` | Base64‑encoded client certificate. Overrides `client-certificate`. |
| `client-key-data` | Base64‑encoded private key. Overrides `client-key`. |
| `certificate-authority-data` | Base64‑encoded CA certificate. Overrides `certificate-authority`. |

**Pros** – the kubeconfig is self‑contained and easy to share (e.g., as a single file).  
**Cons** – secrets are stored in plain text (Base64 is not encryption), so treat the file securely.

---

## How to Generate an Embedded Kubeconfig with `kubectl`

The easiest way to produce a self‑contained kubeconfig is to use `kubectl config` commands with the `--embed-certs=true` flag.

```bash
# Add the cluster (embed CA)
kubectl config set-cluster my-cluster \
  --server=https://k8s.example.com:6443 \
  --certificate-authority=/path/to/ca.crt \
  --embed-certs=true

# Add the user credentials (embed client cert & key)
kubectl config set-credentials my-user \
  --client-certificate=/path/to/client.crt \
  --client-key=/path/to/client.key \
  --embed-certs=true

# Set the context
kubectl config set-context my-context \
  --cluster=my-cluster \
  --user=my-user

# Use it
kubectl config use-context my-context
```

After these commands, your `$HOME/.kube/config` will contain the `-data` fields with Base64 blobs.

---

## Precedence Rules

If both the **file path** and the **data** field are present for the same certificate, the **data** field takes precedence and the file path is ignored.

---

## Security Notes

- **File paths** allow you to keep private keys outside the kubeconfig and set strict file permissions (e.g., `chmod 600`).
- **Embedded keys** are stored in the kubeconfig itself – ensure the file has proper access controls (e.g., `chmod 600` on the file).
- For production, consider using **certificate rotation** and avoid storing long‑lived keys in config files; use tools like **cert‑manager** or **Vault** for dynamic credentials.

---

## Summary Table

| Feature | File‑based | Embedded |
|---------|------------|----------|
| Field names | `client-certificate`, `client-key`, `certificate-authority` | `client-certificate-data`, `client-key-data`, `certificate-authority-data` |
| Values | File paths | Base64‑encoded PEM |
| Portability | Requires separate files | Self‑contained single file |
| Updates | Replace files | Edit the kubeconfig |
| Security | Keys not in config (safer if file permissions set) | Keys are in config (must secure the config file) |
| Generated with | Manual or `kubectl` without `--embed-certs` | `kubectl` with `--embed-certs=true` |

---

Choose the approach that best fits your workflow. For cluster administration and sharing credentials, embedded is very convenient; for strict security policies, file‑based is often preferred.