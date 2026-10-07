Below is a complete, step-by-step tutorial to create a proper **Root CA → Intermediate CA → Server certificate** chain for a Kubernetes Ingress, configure it, and make your browser trust it.

We’ll use OpenSSL. All commands assume a Linux/macOS shell (or Git Bash on Windows). Replace `app.example.com` with your real domain.

---

## 1. Overview of the trust chain

```
Root CA (self‑signed)
   │ signs
Intermediate CA
   │ signs
Server certificate (for your Ingress hostname)
```

- **Root CA** → installed in your browser/OS trust store.
- **Intermediate CA** → sent together with the server certificate by the Ingress.
- **Server certificate** → contains the DNS name(s) of your Ingress (`SAN` – Subject Alternative Name).

The browser trusts the server because it can build the chain:  
`server.crt → intermediate.crt → root.crt (trusted)`.

---

## 2. Prepare directories and variables

```bash
export DOMAIN=app.example.com
export COMPANY="MyOrg"

mkdir -p certs/root certs/intermediate certs/server
cd certs
```

---

## 3. Create the Root CA

### 3.1 Root CA configuration file

```bash
cat > root.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = $COMPANY
OU = IT
CN = $COMPANY Root CA

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
```

### 3.2 Generate Root CA key and self‑signed certificate

```bash
# RSA 4096, valid 20 years
openssl genrsa -out root/root.key 4096
openssl req -x509 -new \
    -key root/root.key \
    -out root/root.crt \
    -days 7300 \
    -sha256 \
    -config root.cnf
```

---

## 4. Create the Intermediate CA

### 4.1 Intermediate CA configuration file

```bash
cat > intermediate.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = $COMPANY
OU = IT
CN = $COMPANY Intermediate CA

[v3_intermediate_ca]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
```

- `pathlen:0` prevents the intermediate CA from issuing further subordinate CAs – good practice.

### 4.2 Generate Intermediate CA key and CSR

```bash
openssl genrsa -out intermediate/intermediate.key 4096
openssl req -new \
    -key intermediate/intermediate.key \
    -out intermediate/intermediate.csr \
    -config intermediate.cnf
```

### 4.3 Sign the Intermediate CA with the Root CA

```bash
openssl x509 -req \
    -in intermediate/intermediate.csr \
    -CA root/root.crt \
    -CAkey root/root.key \
    -CAcreateserial \
    -out intermediate/intermediate.crt \
    -days 3650 \
    -sha256 \
    -extfile intermediate.cnf \
    -extensions v3_intermediate_ca
```

---

## 5. Create the Server Certificate (for the Ingress)

### 5.1 Server certificate configuration file

```bash
cat > server.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = server_cert          # <-- used during CSR generation
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = $COMPANY
OU = IT
CN = $DOMAIN

[server_cert]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash

[server_cert_sign]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[alt_names]
DNS.1 = $DOMAIN
# DNS.2 = www.$DOMAIN
EOF
```

> **Important:** The certificate **must** include the Ingress hostname in `subjectAltName` (`SAN`). Modern browsers ignore `CN` for hostname verification.

### 5.2 Generate Server key and CSR

```bash
openssl genrsa -out server/server.key 2048
openssl req -new \
    -key server/server.key \
    -out server/server.csr \
    -config server.cnf
```

### 5.3 Sign the Server certificate with the Intermediate CA

```bash
openssl x509 -req \
    -in server/server.csr \
    -CA intermediate/intermediate.crt \
    -CAkey intermediate/intermediate.key \
    -CAcreateserial \
    -out server/server.crt \
    -days 397 \
    -sha256 \
    -extfile server.cnf \
    -extensions server_cert
```

---

## 6. Build the certificate chain file

The chain sent by the server must contain **server certificate first**, then the intermediate certificate(s). The root should **not** be included.

```bash
cat server/server.crt intermediate/intermediate.crt > server/fullchain.crt
```

Verify the chain:

```bash
openssl verify -CAfile root/root.crt -untrusted intermediate/intermediate.crt server/server.crt
```

Expected output:

```
server/server.crt: OK
```

---

## 7. Deploy to Kubernetes Ingress

### 7.1 Create a TLS Secret

The secret must contain:
- `tls.crt` → the full chain (`server.crt` + `intermediate.crt`)
- `tls.key` → the server private key

```bash
kubectl create namespace myapp   # if not already created

kubectl create secret tls ingress-tls \
    --namespace myapp \
    --cert=server/fullchain.crt \
    --key=server/server.key
```

### 7.2 Create an Ingress that uses the secret

Save as `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: myapp
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: ingress-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

Apply it:

```bash
kubectl apply -f ingress.yaml
```

Make sure your Ingress controller is installed and the DNS record for `app.example.com` points to the Ingress external IP.

---

## 8. Make your browser trust the Root CA

The certificate chain sent by the server is validated against the **Root CA**. You must import the Root CA certificate into the trust store used by your browser/OS.

### 8.1 Locate the Root CA certificate

```
certs/root/root.crt
```

### 8.2 Install on different platforms

#### Linux (Debian/Ubuntu)

```bash
sudo cp root/root.crt /usr/local/share/ca-certificates/my-root-ca.crt
sudo update-ca-certificates
```

#### Linux (RHEL/CentOS/Fedora)

```bash
sudo cp root/root.crt /etc/pki/ca-trust/source/anchors/my-root-ca.crt
sudo update-ca-trust
```

#### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain root/root.crt
```

#### Windows

1. Double‑click `root.crt`.
2. Click **Install Certificate**.
3. Select **Local Machine** → **Place all certificates in the following store** → **Trusted Root Certification Authorities**.
4. Finish and confirm.

### 8.3 Firefox (if using it)

Firefox uses its own certificate store.

1. Open Firefox → **Settings** → **Privacy & Security**.
2. Scroll to **Certificates** → **View Certificates**.
3. Go to **Authorities** tab → **Import**.
4. Select `root.crt`.
5. Check **Trust this CA to identify websites**.

Chrome, Edge, Safari use the OS trust store, so they will trust the root automatically after the OS import.

---

## 9. Test everything

Restart your browser (or open a new private window), then browse to:

```
https://app.example.com
```

You should see the padlock icon **without any warnings**.

You can also test with `curl`:

```bash
curl -v https://app.example.com
```
```bash
curl --resolve app.example.com:8443:127.0.0.1 https://app.example.com:8443 -kv
```

Look for:

```
*  SSL certificate verify ok.
```

---

## 10. Troubleshooting

| Problem | Likely cause | Solution |
|---------|--------------|----------|
| `SSL certificate verify failed` in curl | Missing root in trust store, or missing intermediate in chain | Import root CA; ensure `fullchain.crt` contains `server.crt` + `intermediate.crt` |
| Browser says “Your connection is not private” but certificate is trusted | Hostname mismatch – certificate SAN does not include the domain | Re‑generate server cert with correct `DNS.x` in `[alt_names]` |
| `unable to get local issuer certificate` | Intermediate CA not sent by server | Recreate secret with proper `fullchain.crt` order |
| Kubernetes Ingress shows default fake certificate | Secret not found, or secret name mismatch | Check `secretName` and namespace |
| `x509: certificate signed by unknown authority` | Root CA not trusted | Import root CA into system/browser |

---

## 11. Optional: Create a single script

You can combine all steps into a script for repeated use. Just change the variables at the top.

```bash
#!/usr/bin/env bash
set -e

export DOMAIN=app.example.com
export COMPANY=MyOrg

mkdir -p certs/root certs/intermediate certs/server
cd certs

# ... (paste all config creation and openssl commands from above) ...
```

---

### Troubleshooting

The difference lies in how TLS **SNI (Server Name Indication)** is set during the handshake.

##### ❌ `curl -H "Host: app.example.com" https://127.0.0.1:8443`

- The URL hostname is `127.0.0.1`.
- Curl uses the URL hostname for **SNI** → it sends `127.0.0.1` in the TLS ClientHello.
- The Ingress controller receives SNI = `127.0.0.1`. It has no certificate configured for that SNI, so it falls back to its **default fake certificate**.
- The `Host` header is set **after** the TLS handshake, in the HTTP layer. It has **no effect** on which certificate the server presents.
- Because the certificate does not match `127.0.0.1`, curl rejects it (unless `-k` is used).

##### ✅ `curl --resolve app.example.com:8443:127.0.0.1 https://app.example.com:8443`

- `--resolve` tells curl: “When connecting to `app.example.com:8443`, actually use IP `127.0.0.1`.”
- Curl now sees the hostname as `app.example.com` (from the URL).
- It sends **SNI = `app.example.com`** during the TLS handshake.
- The Ingress controller finds the certificate for `app.example.com` (from your `ingress-tls` secret) and presents it.
- The certificate is valid for the hostname, so TLS succeeds.
- The HTTP `Host` header is automatically set to `app.example.com` as well.

---

##### Key takeaway

| Command | SNI sent | Certificate selected | Result |
|---------|----------|----------------------|--------|
| `-H "Host: ..."` with IP URL | IP address (`127.0.0.1`) | Fake/default | Fails (cert mismatch) |
| `--resolve` with full hostname | `app.example.com` | Your custom certificate | Works |

**SNI is the critical piece** for selecting the correct TLS certificate. The HTTP `Host` header is irrelevant until after the TLS handshake is completed.

---

##### Additional tip

If you want to keep the IP in the URL but force a specific SNI, you can use `--connect-to`:

```bash
curl --connect-to app.example.com:443:127.0.0.1:8443 https://app.example.com/
```

This tells curl to connect to `127.0.0.1:8443` but still use `app.example.com` for SNI and Host header. However, `--resolve` is simpler and sufficient for testing.