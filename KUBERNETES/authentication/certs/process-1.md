
```text
                 AUTHENTICATION
                       │
                       ▼
              ┌─────────────────┐
              │ Generate Key    │
              │ jane.key        │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ Generate CSR    │
              │ jane.csr        │
              │ CN=Jane         │
              └────────┬────────┘
                       │
                       ▼
              Base64 encode CSR
                       │
                       ▼
              ┌─────────────────┐
              │ Kubernetes CSR  │
              │ resource        │
              └────────┬────────┘
                       │
                       ▼
                 Administrator
                    approves
                       │
                       ▼
              ┌─────────────────┐
              │ Signed cert     │
              │ jane.crt        │
              └────────┬────────┘
                       │
                       │
              jane.key + jane.crt
                       │
                       ▼
                  kubeconfig
                       │
                       ▼
               authenticate as
                     Jane
                       │
                       ▼
                 AUTHORIZATION
                       │
                       ▼
                     RBAC
                       │
              ┌────────┴─────────┐
              ▼                  ▼
          Role/Binding      ClusterRole/Binding
              │                  │
              ▼                  ▼
        namespace access    cluster-wide access
```

---

**Create private key & CSR for user jane**
```bash
openssl genrsa -out jane.key 2048

openssl req -new -key jane.key -out jane.csr -subj "/CN=jane"

openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=example:masters" #With Group

openssl x509 -in <cert-file> -noout -subject
openssl x509 -in <cert-file> -noout -text
```

---

**Get base64 encoded CSR**
```bash
cat jane.csr | base64 | tr -d "\n"
```

---

**Create CertificateSigningRequest resource for jane**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  request: <base64_encoded_csr>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - client auth
EOF
```
**Notes:**
- `request:` should contain the actual base64-encoded CSR output (from `cat jane.csr | base64 | tr -d '\n'`)
- `expirationSeconds: 86400` = 1 day validity for the certificate
- `signerName: kubernetes.io/kube-apiserver-client` tells Kubernetes this cert is for a client (user) authenticating to the API server
- `usages: - client auth` restricts the cert to client authentication only

---

**Check & approve CSR for jane**
```bash
kubectl get csr jane

kubectl certificate approve jane
```

---

**Fetch certificate for poweruser**
```bash
kubectl get csr jane -o jsonpath='{.status.certificate}' | base64 -d > jane.crt
```

---

**Verify jane's certificate subject**
```bash
openssl x509 -in jane.crt -text -noout | grep Subject | grep -v "Public Key Info"
```

---

**Add jane to kubeconfig**
```bash
kubectl config set-credentials jane --client-key=jane.key --client-certificate=jane.crt --embed-certs=true

kubectl config set-context jane --cluster=minikube --user=jane
```

---

**Verify jane permissions using --user**
```bash
kubectl auth can-i create pods --user=jane
kubectl auth can-i create deployments --user=jane
kubectl auth can-i delete secrets --user=jane
```