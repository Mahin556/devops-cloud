# Kubernetes Secrets: Detailed Guide

Kubernetes Secrets are specialized objects designed to **store sensitive data securely** within a Kubernetes cluster. Unlike ConfigMaps, Secrets can store data that should not be exposed publicly, such as passwords, API tokens, certificates, and SSH keys. Secrets can be **mounted as volumes**, **exposed as environment variables**, or **referenced by other Kubernetes objects**.

| **Type**                                | **Usage**                                                                     |
| --------------------------------------- | ----------------------------------------------------------------------------- |
| **Opaque**                              | For storing user-defined arbitrary data (default type).                       |
| **kubernetes.io/service-account-token** | Stores ServiceAccount tokens for authenticating with the Kubernetes API.      |
| **kubernetes.io/dockercfg**             | Stores serialized `~/.dockercfg` file for Docker registry authentication.     |
| **kubernetes.io/dockerconfigjson**      | Stores serialized `~/.docker/config.json` for Docker registry authentication. |
| **kubernetes.io/basic-auth**            | Stores username/password for basic HTTP authentication.                       |
| **kubernetes.io/ssh-auth**              | Stores SSH private keys for SSH authentication.                               |
| **kubernetes.io/tls**                   | Stores TLS certificates and private keys for encrypted communication.         |
| **bootstrap.kubernetes.io/token**       | Stores bootstrap tokens for joining new nodes to a cluster.                   |

---

## 1. **Opaque Secrets**

**Description:**
* Default type
* Default Secret type when no specific type is provided.
* Used for storing arbitrary user-defined key-value data, like API keys or database credentials.

**Structure Example:**
```bash
kubectl create secret generic my-opaque-secret \
  --from-literal=username=admin \
  --from-literal=password=1f2d1e2e67df

```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-opaque-secret
type: Opaque
data:
  username: YWRtaW4=           # "admin" encoded in Base64
  password: MWYyZDFlMmU2N2Rm   # "1f2d1e2e67df" encoded in Base64
```

**Use Case:**

* Storing generic sensitive data like API keys, application passwords, or configuration tokens.

---

## 2. **Service Account Token Secrets**

* Used to associate a ServiceAccount with a Secret that stores its authentication token, allowing Pods to communicate with the Kubernetes API securely.

* Example Use Case: Store ServiceAccount tokens for API authentication.

* `kubernetes.io/service-account.name` annotation must reference an existing service account.

* As of Kubernetes v1.22+, you should use TokenRequest API for short-lived tokens instead of static tokens.

```bash
kubectl create secret generic my-sa-token-secret \
  --type=kubernetes.io/service-account-token \
  --from-literal=extra=bar
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sa-token-secret
  annotations:
    kubernetes.io/service-account.name: my-service-account
type: kubernetes.io/service-account-token
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token-secret
  annotations:
    kubernetes.io/service-account.name: "my-service-account"
type: kubernetes.io/service-account-token
data:
  extra: YmFyCg==
```
* Auto-generated legacy tokens (pre-v1.24) are now invalidated automatically after a year and cleaned up.

**Use Case:**

* When pods need to authenticate to the Kubernetes API server using a service account.

---

## 3. **Docker Config Secrets**

**Description:**

* Stores credentials for accessing **private container registries**(e.g., Docker Hub, AWS ECR, GCR)..
* Two possible types:
  * `kubernetes.io/dockercfg` → legacy Docker config.
  * `kubernetes.io/dockerconfigjson` → modern JSON-based Docker config.

**Structure Example (dockerconfigjson):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-docker-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>

---

apiVersion: v1
kind: Secret
metadata:
  name: my-docker-config-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJodHRwczovL2V4YW1wbGUvdjEvIjp7ImF1dGgiOiJvcGVuc2VzYW1lIn19fQo=

```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-config-secret
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "https://index.docker.io/v1/": {
          "username": "my-username",
          "password": "my-password",
          "auth": "bXktdXNlcm5hbWU6bXktcGFzc3dvcmQ="
        }
      }
    }
```

**Use Case:**

* Pull private Docker images securely in Kubernetes pods.

**Command to Create from CLI:**

```bash
kubectl create secret docker-registry my-docker-secret \
  --docker-server=<registry_url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>

kubectl create secret docker-registry my-docker-config-secret \
  --docker-server=my-registry.example.com \
  --docker-username=my-username \
  --docker-password=my-password \
  --docker-email=my-email@example.com
```

---

## 4. **Basic Authentication Secrets**

* Used for storing username and password combinations for basic HTTP authentication.

* Example Use Case: Store credentials for accessing a web service.

* `username` → Username for authentication.
* `password` → Password or token.

```bash
kubectl create secret generic my-basic-auth-secret \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=admin \
  --from-literal=password=t0p-Secretstore
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-basic-auth
type: kubernetes.io/basic-auth
data:
  username: YWRtaW4=     # admin
  password: MWYyZDFlMmU2N2Rm
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth-secret
type: kubernetes.io/basic-auth
stringData:
  username: myuser
  password: mypassword
```

**Use Case:**

* Authenticate applications or services requiring basic HTTP authentication.

---

## 5. **SSH Authentication Secrets**

* Used for storing SSH private keys required to access remote systems securely.

* `ssh-privatekey` → Private key used for SSH authentication.


```bash
kubectl create secret generic my-ssh-auth-secret \
  --type=kubernetes.io/ssh-auth \
  --from-file=ssh-privatekey=path/to/private/key
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-ssh-secret
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: <base64-encoded-private-key>
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ssh-auth-secret
type: kubernetes.io/ssh-auth
stringData:
  ssh-privatekey: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA7xyzasv..
    -----END RSA PRIVATE KEY-----
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ssh-pod
spec:
  containers:
    - name: my-container
      image: busybox
      command: ["cat", "/etc/ssh/ssh-privatekey"]
      volumeMounts:
        - name: ssh-volume
          mountPath: "/etc/ssh"
          readOnly: true
  volumes:
    - name: ssh-volume
      secret:
        secretName: ssh-auth-secret
```

**Use Case:**

* Securely access servers, Git repositories, or other resources over SSH.

---

## 6. **TLS Secrets**

* Used to store X.509 certificates and private keys for securing communication via TLS/SSL.
* Commonly referenced by Ingress controllers.


* `tls.crt` → The TLS certificate.
* `tls.key` → The TLS private key.

```bash
kubectl create secret tls tls-secret \
  --cert=path/to/cert/file \
  --key=path/to/key/file
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
stringData:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    MIIC+zCCAeOgAwIBAgIJAK6EXAMPLECERTIFICATE
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvAIBADANBgkqhkiG9w0BAQEFAASCEXAMPLEPRIVATEKEY
    -----END PRIVATE KEY-----

---
apiVersion: v1
kind: Pod
metadata:
  name: tls-pod
spec:
  containers:
    - name: nginx-container
      image: nginx
      volumeMounts:
        - name: tls-volume
          mountPath: "/etc/tls"
          readOnly: true
  volumes:
    - name: tls-volume
      secret:
        secretName: tls-secret

```

**Use Case:**

* Secure services with HTTPS.
* Terminate TLS in Ingress controllers or Load Balancers.

---

## 7. **Bootstrap Token Secrets**


* Used to register and authenticate new nodes joining the cluster during the bootstrap process.

* Typically created in `kube-system`.
* Named like `bootstrap-token-<token-id>`.

```bash
kubectl create secret generic bootstrap-token-6emitej \
  --type=bootstrap.kubernetes.io/token \
  --from-literal=token-id=5emitej \
  --from-literal=token-secret=kq4gihvszzgn1p0r \
  --from-literal=usage-bootstrap-authentication=true \
  --from-literal=usage-bootstrap-signing=true
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-abc123
  namespace: kube-system
type: bootstrap.kubernetes.io/token
data:
  token-id: YWJjMTIz      # abc123
  token-secret: c2VjcmV0   # secret
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-abcdef
  namespace: kube-system
type: bootstrap.kubernetes.io/token
stringData:
  description: "Bootstrap token for joining nodes"
  token-id: abcdef
  token-secret: 0123456789abcdef
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-6emitej
  namespace: kube-system
type: bootstrap.kubernetes.io/token
data:
  token-id: NWVtaXRq
  token-secret: a3E0Z2lodnN6emduMXAwcg==
  usage-bootstrap-authentication: dHJ1ZQ==
  usage-bootstrap-signing: dHJ1ZQ==
```
```bash
kubectl create secret generic bootstrap-token-6emitej \
  --type=bootstrap.kubernetes.io/token \
  --from-literal=auth-extra-groups=system:bootstrappers:kubeadm:default-node-token \
  --from-literal=expiration=2020-09-13T04:39:10Z \
  --from-literal=token-id=5emitej \
  --from-literal=token-secret=kq4gihvszzgn1p0r \
  --from-literal=usage-bootstrap-authentication=true \
  --from-literal=usage-bootstrap-signing=true
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-6emitej
  namespace: kube-system
type: bootstrap.kubernetes.io/token
data:
  auth-extra-groups: c3lzdGVtOmJvb3RzdHJhcHBlcnM6a3ViZWFkbTpkZWZhdWx0LW5vZGUtdG9rZW4=
  expiration: MjAyMC0wOS0xM1QwNDozOToxMFo=
  token-id: NWVtaXRq
  token-secret: a3E0Z2lodnN6emduMXAwcg==
  usage-bootstrap-authentication: dHJ1ZQ==
  usage-bootstrap-signing: dHJ1ZQ==
```

**Use Case:**

* Securely add new nodes to a cluster during bootstrap.

---

## Key Features of Kubernetes Secrets

| Feature                   | Description                                                                  |
| ------------------------- | ---------------------------------------------------------------------------- |
| **Base64-encoded**        | Secrets are encoded in Base64 for storage; not encrypted by default.         |
| **Volume Mounts**         | Secrets can be mounted as files inside pods.                                 |
| **Environment Variables** | Secrets can be exposed to containers as environment variables.               |
| **Immutability**          | Secrets can be made immutable (`immutable: true`) to prevent modification.   |
| **Dynamic Updates**       | Updates to a Secret automatically reflect in mounted volumes (if supported). |
| **Namespace-scoped**      | Secrets exist within a namespace.                                            |

---

## Security Considerations

* By default, Secrets are stored in **etcd in plaintext**. Enable **encryption at rest** in the kube-apiserver for production.
* Control access using **RBAC policies** to prevent unauthorized access.
* Consider using **external secret management** tools (e.g., HashiCorp Vault, AWS Secrets Manager) for high security.
* Avoid storing sensitive data in ConfigMaps.


### References:
- https://spacelift.io/blog/kubernetes-secrets
- https://www.geeksforgeeks.org/devops/kubernetes-secrets/
- https://www.perfectscale.io/blog/kubernetes-secrets