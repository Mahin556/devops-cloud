By default, Kubernetes stores Secrets (and all cluster metadata) in etcd — the cluster’s backing key-value database.
Without encryption, etcd stores this data in plain base64, which means anyone with access to etcd storage or backups can decode your secrets easily.

So, enabling encryption at rest ensures that:

Secret values are encrypted before being written to etcd.

They can only be decrypted by the API server using the configured encryption key.

Even if someone steals your etcd snapshot, the data remains unreadable.

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-key>
      - identity: {}
```
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
      - deployments
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-secret>
      - identity: {}
```
| **Field**            | **Description**                                                                                                                   |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `apiVersion`, `kind` | The API config type for encryption settings.                                                                                      |
| `resources`          | The list of Kubernetes resource types to encrypt — usually just `secrets`, but you can also encrypt ConfigMaps, Deployments, etc. |
| `providers`          | Defines the **encryption providers** (methods) to use, in order.                                                                  |
| `aescbc`             | The **encryption provider** (AES in CBC mode).                                                                                    |
| `keys`               | Encryption keys used by the provider.                                                                                             |
| `secret`             | The actual encryption key, **base64-encoded**.                                                                                    |
| `identity`           | Acts as a fallback (no encryption) for already-encrypted data migration or compatibility.                                         |


* Generate a Secure AES Key
  ```bash
  head -c 32 /dev/urandom | base64
  ```
  * This produces a 256-bit AES key encoded in base64.
  * Copy that and place it in your YAML file under secret:.

<br>

* Applying the Encryption Configuration
  * Save(encryption-config.yaml) in a secure location on the control-plane node:
    ```bash
    /etc/kubernetes/encryption-config.yaml
    ```
  * Edit the API server manifest
    ```bash
    vim /etc/kubernetes/manifests/kube-apiserver.yaml
    ```
    ```bash
    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
    ```
  * Restart API server
    Because the control plane components in kubeadm setups are static pods, editing the manifest will automatically trigger a restart of the API server.

<br>

* Verify That Encryption Is Working
  * Create a new Secret:
    ```bash
    kubectl create secret generic test-secret --from-literal=username=admin
    ```
  * Get the raw data from etcd:
    ```bash
    ETCDCTL_API=3 etcdctl get /registry/secrets/default/test-secret \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key | hexdump -C
    ```
  * You should see nonsensical binary data, not readable base64 strings.

<br>

* Encrypting Existing Secrets
  Existing secrets in etcd remain unencrypted until rewritten.
  You can re-encrypt all Secrets with:
  ```bash
  kubectl get secrets --all-namespaces -o json | kubectl replace -f -
  ```
  This forces Kubernetes to re-store them using the new encryption policy.

* Supported Encryption Providers
  | Provider    | Description                               | Strength           |
  | ----------- | ----------------------------------------- | ------------------ |
  | `aescbc`    | AES-CBC with PKCS#7 padding (recommended) | 🔐 Strong          |
  | `aesgcm`    | AES-GCM (authenticated encryption)        | 🔐 Strong, faster  |
  | `secretbox` | XSalsa20 and Poly1305 (NaCl)              | 🔐 Strong, simpler |
  | `identity`  | No encryption (plaintext)                 | ⚠️ Not secure      |

  The first provider in the list is used to encrypt new data.
  Kubernetes automatically detects previously encrypted data using provider metadata.



### References:
- https://spacelift.io/blog/kubernetes-secrets
- https://medium.com/@ravipatel.it/mastering-kubernetes-secrets-a-comprehensive-guide-b0304818e32b