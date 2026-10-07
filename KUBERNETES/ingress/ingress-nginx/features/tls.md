## 🔐 SSL Termination vs. SSL Passthrough in NGINX Ingress

The NGINX Ingress Controller can handle TLS in two ways:

- **SSL Termination (default)** – the Ingress terminates the TLS connection, decrypts traffic, and forwards **plain HTTP** to the backend service.
- **SSL Passthrough** – the Ingress **does not** decrypt traffic; it forwards the encrypted TLS stream directly to the backend, which must handle its own TLS.

---

### 1. SSL Termination (Default)

**How it works:**
- The client establishes a TLS connection with the Ingress controller.
- The Ingress controller decrypts the request and forwards it as plain HTTP to the backend service (usually on port 80).
- This is the **default behaviour** and requires you to provide a TLS certificate (via a Kubernetes Secret) in the Ingress resource.

**Example (termination):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls-secret   # contains certificate & key
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80   # HTTP (not TLS)
```

**Benefits:**
- Centralised certificate management.
- Reduced load on backends (no TLS overhead).
- Allows path‑based routing and other features (rewrites, headers, etc.).

---

### 2. SSL Passthrough

**How it works:**
- The client establishes a TLS connection with the Ingress controller.
- The Ingress controller **does not** decrypt the traffic; it forwards the encrypted TCP stream directly to the backend.
- The backend must have its own TLS certificate and handle the TLS termination itself.

**To enable SSL Passthrough:**
1. **Add the annotation** to your Ingress:
   ```yaml
   metadata:
     annotations:
       nginx.ingress.kubernetes.io/ssl-passthrough: "true"
   ```
2. **Enable the feature in the controller** (disabled by default).  
   You must start the controller with the flag:
   ```
   --enable-ssl-passthrough
   ```
   When using Helm, set:
   ```bash
   --set controller.enableSslPassthrough=true
   ```

**Example (passthrough):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress-passthrough
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-tls-service
            port:
              number: 443   # Note: backend listens on 443 (TLS)
```

**Important:**
- The `tls` section in the Ingress **is ignored** when `ssl-passthrough` is enabled – you don't need a Secret in the Ingress.
- The controller forwards traffic based **only on the SNI hostname** (the `Host` header inside TLS). It cannot perform **path‑based routing** because the traffic is encrypted – NGINX cannot see the path.
- Only traffic to port **443** is affected; other ports are not affected.

**Benefits:**
- End‑to‑end encryption (the backend sees the original TLS session).
- Useful when you cannot or do not want to manage certificates at the edge (e.g., compliance, legacy backends).

**Drawbacks:**
- **No path‑based routing** – all traffic for the host goes to a single backend service.
- **SNI required** – the client must support SNI.
- **Performance** – the controller acts as a TCP proxy, so it cannot apply HTTP‑level optimisations (compression, caching, etc.).

---

### 3. When to Use Which

| Scenario | Recommended |
|----------|-------------|
| Microservices with internal HTTP traffic, central cert management | Termination (default) |
| Need path‑based routing with TLS | Termination (you can use different paths) |
| Backend requires end‑to‑end encryption (e.g., financial, regulatory) | Passthrough |
| Legacy service that already has its own TLS certificate | Passthrough |
| You want to inspect or modify HTTP traffic (headers, rewrites) | Termination (since you decrypt) |

---

### 4. Combining Both (If Needed)

You can have **some** Ingress resources with termination and **some** with passthrough on the same controller – just annotate accordingly. The `--enable-ssl-passthrough` flag is global, but the annotation controls which Ingress uses it.

---

### 5. Verification

- **Termination** – check that the backend sees plain HTTP (e.g., no `HTTPS` or `X-Forwarded-Proto` header? Actually, the controller adds `X-Forwarded-Proto: https` if the original request was TLS).
- **Passthrough** – check that the backend sees the original TLS connection (e.g., `HTTPS` environment variable is set, or the certificate is from the client).

---

### 6. Important Note on `X-Forwarded-*` Headers

With termination, the Ingress adds headers like `X-Forwarded-For` and `X-Forwarded-Proto` to help the backend understand the original client IP and protocol. With passthrough, these are **not** added because NGINX cannot inspect the encrypted payload.

---

To secure a Kubernetes Ingress with TLS, you need a server certificate and private key. You can use openssl to create a self-signed certificate for testing, or generate a Certificate Signing Request (CSR) to obtain a certificate from a trusted Certificate Authority (CA) for production.

There is 2 ways to do it

### First: Generate a Private Key and Certificate
The most straightforward method for a self-signed certificate (ideal for development or internal use) is a single openssl req command. This creates both the private key (tls.key) and the public certificate (tls.crt) at once.

Important: Modern browsers and clients require the certificate to include a Subject Alternative Name (SAN). The `-addext` flag below ensures the certificate is valid for your specified hostname.

```bash
# Set your desired hostname (e.g., app.example.com)
HOST="my-services.mahinraza.online"

# Generate the self-signed certificate and key in PEM format
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=${HOST}/O=${HOST}" \
  -addext "subjectAltName = DNS:${HOST}"
```

`-x509`: Creates a self-signed certificate directly.

`-nodes`: Creates the private key without a passphrase (necessary for Kubernetes to load it automatically).

`-days 365`: Sets the certificate validity to one year.

`-newkey rsa:2048`: Generates a new 2048-bit RSA private key.

`-addext "subjectAltName = DNS:${HOST}"`: Adds the critical SAN field.

After running this, you will have two files: tls.key (the private key) and tls.crt (the certificate).

### Second: Generate a Certificate Signed by Your Own CA (Optional)
For a more production-like setup, you can create your own Certificate Authority (CA) to sign the server certificate. This is useful for internal environments where you can distribute the CA certificate to clients.

1. Generate the CA's private key and root certificate:

```bash
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 1825 -out ca.crt -subj "/CN=MyInternalCA"
```

2. Create a Certificate Signing Request (CSR) for your Ingress host:

First, create a configuration file (csr.cnf) to include the SAN.

```ini
# csr.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = app.example.com

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = app.example.com
```

Then, generate the key and CSR:

```bash
openssl genrsa -out tls.key 2048
openssl req -new -key tls.key -out tls.csr -config csr.cnf
```

3. Sign the CSR with your CA to create the server certificate:

```bash
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out tls.crt -days 365 -sha256 -extfile csr.cnf -extensions v3_req
```

Now you have a tls.crt signed by your own CA.

---

### Create the Kubernetes TLS Secret
Kubernetes Ingress controllers expect the certificate and key to be stored in a kubernetes.io/tls type Secret. The kubectl create secret tls command is the standard way to do this.

```bash
kubectl create secret tls my-services-mahinraza-online-tls-secret \
  --cert=tls.crt \
  --key=tls.key
```

`my-ingress-tls:` The name you will reference in your Ingress resource.

`--cert=tls.crt:` The path to your certificate file.

`--key=tls.key:` The path to your private key file.

---

### Configure the Ingress Resource
Finally, update your Ingress YAML manifest to reference the newly created Secret. This tells the Ingress controller to use this certificate for TLS termination.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
spec:
  ingressClassName: nginx # Or your specific ingress controller class
  tls:
  - hosts:
    - app.example.com
    secretName: my-ingress-tls # Must match the Secret name from Step 3
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80
```

---

### Verify the Setup
After applying the Ingress, you can verify the certificate is being served correctly.

Find your Ingress IP/Hostname:

```bash
kubectl get ingress my-app-ingress
```

Inspect the served certificate:

Replace <INGRESS_IP_OR_HOSTNAME> with the address from the previous command.

```bash
openssl s_client -connect <INGRESS_IP_OR_HOSTNAME>:443 -servername app.example.com -showcerts
```

Look for the "Subject" and "X509v3 Subject Alternative Name" fields in the output to confirm they match your hostname.