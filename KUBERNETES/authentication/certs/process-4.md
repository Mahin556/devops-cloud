
### **Granting Cluster Access to a New User using Certificates() and RBAC**

![Alt text](/images/34a.png)

---

**Granting Cluster Access to a New User (Seema) using Certificates and RBAC**

**Generates a Private Key**
```bash
openssl genrsa -out seema.key 2048
```
This generates a 2048-bit RSA **private key**, saved to `seema.key`. This key will be used to generate a certificate signing request (CSR), CSR then used to generate a X.509 Certificate for the user and later this certificate used to authenticate to the Kubernetes cluster. 
Private key must remain **private and secure**.

---

**Seema Generates a Certificate Signing Request (CSR)**
```bash
openssl req -new -key seema.key -out seema.csr -subj "/CN=seema/O=groupname"

#Add user to multiple groups
openssl req -new -key seema.key -out seema.csr -subj "/CN=seema/O=group1/O=group2" 
```
Seema uses her private key to create a **CSR**. The `-subj "/CN=seema"` sets the **Common Name (CN)** to `seema`, which becomes her Kubernetes username. `/O=groupname` group which seema part of. The generated CSR contains her public key and identity, and will be signed by a Kubernetes cluster admin.

---

**Verify CSR**
https://certlogik.com/decoder/

```bash
openssl req -in seema.csr -noout -text
```

---

**Seema Shares the CSR with the Kubernetes Admin**

```bash
cat seema.csr | base64 | tr -d "\n"
```
The CSR must be **base64-encoded** to embed it into a Kubernetes object. This command converts the CSR into a single-line base64 string, stripping newlines with `tr -d "\n"`—a necessary step for YAML formatting.

---

**Kubernetes Admin Creates the CSR Object in Kubernetes**

* **First way(using `CertificateSigningRequest` resource)**
  ```yaml
  apiVersion: certificates.k8s.io/v1
  kind: CertificateSigningRequest
  metad: <BASE64_ENCODED_CSR>
    signerName: kubernetes.io/kube-apiserver-client
    expirationSeconds: 7776000
    usages:
    - client authata:
    name: seema
  spec:
    request
  ```
  The admin creates a Kubernetes `CertificateSigningRequest` object.
  * `request` is the base64-encoded CSR.
  * `signerName: kubernetes.io/kube-apiserver-client` instructs Kubernetes to treat this as a **client authentication** request.
  * `usages` defines that this certificate will be used for **client authentication**, not server TLS or other use cases.
  * `expirationSeconds` sets the certificate’s validity to **90 days** (7776000 seconds).

* **Second way(using `openssl` utility)**
  ```bash
  # Generate user certificate signed by Kubernetes CA
  openssl x509 -req \
    -in seema.csr \
    -CA /etc/kubernetes/pki/ca.crt \
    -CAkey /etc/kubernetes/pki/ca.key \
    -CAcreateserial \
    -out seema.crt \
    -days 365
  ```

---

**Verify Certificate**
```bash
openssl x509 -in seema.crt -text -noout
```


**Kubernetes Admin Approves the CSR**
```bash
kubectl certificate approve seema
```
This command **approves and signs** the certificate request. Kubernetes issues a certificate for Seema, valid per the defined usage and expiration settings.

---

**Admin Retrieves and Shares the Signed Certificate**
```bash
kubectl get csr seema -o jsonpath='{.status.certificate}' | base64 -d > seema.crt
```
The admin retrieves the **signed certificate** from the CSR’s status, decodes it from base64, and saves it as `seema.crt`. This certificate, along with `seema.key`, is sent back to Seema for kubeconfig configuration.

---

**Fetch the CA Certificate**
```bash
kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | base64 --decode > ca.crt
```
Go to:- https://certlogik.com/decoder/
  * kubernetes CA
  * Root CA

---

**Seema Configures Her `kubeconfig` with Credentials and Cluster Info**

```bash
kubectl config set-credentials seema \
  --client-certificate=seema.crt \
  --client-key=seema.key \
  --certificate-authority=ca.crt \
  --embed-certs=true

kubectl config set-cluster kind-my-second-cluster \
  --server=https://127.0.0.1:59599 \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=~/.kube/config

kubectl config set-context seema@kind-my-second-cluster-context \
  --cluster=kind-my-second-cluster \
  --user=seema \
  --namespace=default
```
```bash
kubectl config view -ojsonpath='{.clusters[0].cluster.server}{"\n"}'

kubectl config set-cluster kubernetes \
  --server=$(kubectl config view -ojsonpath='{.clusters[0].cluster.server}') \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=./config-new

kubectl config set-credentials seema \
  --client-certificate=seema.crt \
  --client-key=seema.key \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=./config-new

kubectl config set-context seema@kubernetes \
  --cluster=kubernetes \
  --user=seema \
  --namespace=default \
  --kubeconfig=./config-new

kubectl config use-context seema@kubernetes --kubeconfig=config-new

kubectl config get-contexts --kubeconfig=config-new

kubectl get pods --kubeconfig=config-new

KUBECONFIG=config-new kubectl get pods
kubectl get pods

kubectl --v=6 get pods #To see which kube-config file kubectl loaded
```

These commands configure the **user credentials**, **cluster endpoint**, and **context** in Seema’s `kubeconfig`:

* The first command tells kubectl how to authenticate Seema using her certificate/key.
* The second registers the cluster endpoint using the correct CA.
* The third defines a context associating the user, cluster, and default namespace.

---

**Admin Creates a Role and RoleBinding for seema**

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "delete"]
```
```bash
# Create Role with read-only pod access
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  --namespace=default
```
```bash
# View Role YAML
kubectl get role pod-reader -o yaml
```
```bash
# Bind Role to a user
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --user=seema \
  --namespace=default
```
The **Role** allows Seema to **get**, **list**, and **delete** pods in the `default` namespace.
The **RoleBinding** assigns this Role to Seema's username (`CN=seema`), authorizing her actions.

```bash
# Create Role using inline YAML (secret viewer)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-viewer-user
  namespace: default
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
EOF
```
```bash
# Create Role using inline YAML (secret viewer)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-full-access-group
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
EOF
```

```bash
# Bind Role to User
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: limited-secret-viewer
  namespace: default
subjects:
- kind: User
  apiGroup: rbac.authorization.k8s.io
  name: seema
roleRef:
  kind: Role
  name: secret-viewer-user
  apiGroup: rbac.authorization.k8s.io
EOF
```
```bash
# Bind Role to Group
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-full-access
  namespace: default
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: group1
roleRef:
  kind: Role
  name: pod-full-access-group
  apiGroup: rbac.authorization.k8s.io
EOF
```


---

**Admin Verifies Authorization with `can-i`**

```bash
kubectl auth can-i delete pods --namespace=default --as=seema
```
This command is run by the **admin** to simulate whether Seema is allowed to **delete pods** in the `default` namespace.

* `--as=seema` impersonates Seema’s user identity.
* This confirms that the **RBAC permissions** are set correctly before Seema starts using the cluster.

```bash
# Check RBAC permission (delete deployment)
kubectl auth can-i delete deployments/nginx \
  --as=system:serviceaccount:demo:sam \
  --namespace=demo

# Check RBAC permission (create deployment)
kubectl auth can-i create deployments/nginx \
  --as=system:serviceaccount:demo:sam \
  --namespace=demo

# Check if ServiceAccount can get secrets
kubectl auth can-i get secret \
  --as=system:serviceaccount:demo:sam \
  --namespace=demo

# Check if ServiceAccount can list pods
kubectl auth can-i list pods \
  --as=system:serviceaccount:demo:sam \
  --namespace=demo

# Check if ServiceAccount can delete deployments
kubectl auth can-i delete deployment \
  --as=system:serviceaccount:demo:sam \
  --namespace=demo

# Incorrect resource type (error shown in screenshot)
kubectl get rb

# Get RoleBindings in default namespace
kubectl get rolebinding
```
```bash
# Create a Pod using ServiceAccount "sam"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: demo
spec:
  serviceAccountName: sam
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
EOF
```

---

**Seema Switches to Her Configured Context**

```bash
kubectl config use-context seema@kind-my-second-cluster-context
```

This sets Seema's **active context** to the one defined earlier, allowing `kubectl` to use her certificate and connect to the right cluster/namespace.

---

**Optional: Use REST API or Alternate `kubeconfig` Files**

```bash
curl https://<API-SERVER-IP>:<PORT>/api/v1/namespaces/default/pods \
  --cacert ca.crt --cert seema.crt --key seema.key
```
*Seema can authenticate with the cluster directly via API using her certificate.*

```bash
kubectl get pods --kubeconfig=myconfig.yaml
```
*She can manage multiple clusters by specifying alternate kubeconfig files.*

```bash
curl --cacert /etc/kubernetes/pki/ca.crt \
     --cert seema.crt \
     --key seema.key \
     https://172.30.1.2:6443/api/v1
```
```bash
curl --cacert /etc/kubernetes/pki/ca.crt \
     --cert seema.crt \
     --key seema.key \
     https://172.30.1.2:6443/version
```
```bash
curl --cacert /etc/kubernetes/pki/ca.crt \
     --cert seema.crt \
     --key seema.key \
     https://172.30.1.2:6443/api/v1/namespaces/default/pods
```
```bash
curl -X POST \
  --cacert /etc/kubernetes/pki/ca.crt \
  --cert seema.crt \
  --key seema.key \
  -H "Content-Type: application/json" \
  -d '{
        "apiVersion":"v1",
        "kind":"Pod",
        "metadata":{"name":"test-pod"},
        "spec":{
          "containers":[{"name":"nginx","image":"nginx"}]
        }
      }' \
  https://172.30.1.2:6443/api/v1/namespaces/default/pods
```
```bash
curl --cacert /etc/kubernetes/pki/ca.crt \
     --cert <(kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d) \
     --key  <(kubectl config view --raw -o jsonpath='{.users[0].user.client-key-data}' | base64 -d) \
     https://172.30.1.2:6443/api
```

---

**Check Certificate Expiry**

```bash
openssl x509 -noout -dates -in seema.crt
```

This displays the `notBefore` and `notAfter` dates for the certificate, helping Seema monitor its expiration.

---

### **Conclusion**

We’ve just completed a full, practical flow to securely grant a user access to a Kubernetes cluster:
from generating keys and certificates, to configuring kubeconfig, and finally applying RBAC permissions.
This knowledge is foundational for any admin responsible for managing access in production clusters.


