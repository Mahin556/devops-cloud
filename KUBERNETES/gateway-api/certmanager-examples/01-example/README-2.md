
- **cert-manager** — for certificate management.
- **Gateway API** — for routing and TLS termination.
- **Let’s Encrypt** — as the certificate issuer.

cert-manager is a cloud-native certificate management solution that runs on Kubernetes and OpenShift. It creates and renews TLS certificates automatically.

---

### What cert-manager Does
cert-manager can provide:
- **TLS / HTTPS** for services behind **Ingress** or **Gateway API**.
- **Mutual TLS (mTLS)** between two pods for service-to-service communication.
- **mTLS in a service mesh** solution.

If you are running Gateway API in Kubernetes, you need a certificate to enable HTTPS on web endpoints. cert-manager creates that certificate and renews it before expiry.

---

### Issuers
With cert-manager, you configure **Issuers** or **ClusterIssuers**.
- An Issuer defines where certificates come from.
- The most popular issuer is the **ACME issuer**, which includes **Let’s Encrypt**.

cert-manager supports many issuers, including:
- **Let’s Encrypt** (ACME)
- **AWS**
- **Google Cloud Certificates**
- **HashiCorp Vault**
- **Azure Key Vault**

Some issuers are built into cert-manager. To get a certificate, you must prove you own the domain.

---

### Let’s Encrypt
Let’s Encrypt is a nonprofit solution providing free TLS certificates for websites worldwide.

With Let’s Encrypt and cert-manager, there are two main ways to prove domain ownership:
1. **DNS challenge** — easiest.
   - Requires an API token to your DNS provider, e.g., Cloudflare.
   - You create a Kubernetes secret with the API token.
   - The Issuer points to that token.
   - cert-manager and Let’s Encrypt perform the challenge directly with the DNS provider.
2. **HTTP challenge** — more complex.
   - Let’s Encrypt makes an HTTP call to test whether you own the domain and the server behind it.
   - Requires clear line of sight for HTTP and HTTPS to hit your Gateway API.
   - Needs port 80 and 443 open and correctly routed.

This guide uses the **HTTP challenge** because it involves Gateway API.

---

### Load Balancer and DNS Notes

Local setup:
1. Get your home IP:
   ```bash
   curl ifconfig.co
   ```
2. In your DNS provider, e.g., Cloudflare:
   - Create an **A record** or **CNAME**.
   - Point it to your load balancer / IP.
3. On your router:
   - Set up port forwarding for ports 80 and 443.
   - Forward to the local IP and port of the Kubernetes NodePort service.

This ensures Let’s Encrypt traffic reaches your Gateway API in the kind cluster.

---

### How the HTTP Challenge Works
1. cert-manager asks Let’s Encrypt to perform a challenge.
2. Let’s Encrypt says: “Host this secret file on your cluster.”
3. cert-manager uses Gateway API to create a **temporary HTTPRoute** to expose that file.
4. cert-manager tells Let’s Encrypt: “We are ready for the challenge.”
5. Let’s Encrypt performs an HTTP request to find that file.
6. If it gets an **HTTP 200**, the challenge is successful.
7. cert-manager removes the temporary HTTPRoute.
8. Let’s Encrypt issues the certificate back to cert-manager.
9. cert-manager creates a **Kubernetes TLS secret**.
10. The Gateway uses that secret for HTTPS.

---

### Create an Issuer
Create a **ClusterIssuer** for Let’s Encrypt.

Example YAML concepts:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: you@example.com
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: gateway-api
            namespace: default
```

Key points:
- Points to the ACME server.
- Uses `http01` solver.
- For HTTP challenge, tells cert-manager which Gateway API to use.
- For DNS challenge, you would provide a secret for the DNS provider API token instead.

Apply:
```bash
kubectl apply -f clusterissuer.yaml
```

Check:
```bash
kubectl describe clusterissuer letsencrypt
```

Look for:
- `Accepted`
- ACME account registered

---

### Create a Certificate Request
Create a **Certificate** object.

Example YAML concepts:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: default
spec:
  secretName: example-tls
  dnsNames:
  - test.example.com
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
```

Important:
- `secretName` must match the TLS secret name used in the Gateway.
- `dnsNames` is the domain you want a certificate for.
- `issuerRef` points to the ClusterIssuer.

Apply:
```bash
kubectl apply -f certificate.yaml
```

---

### Troubleshooting the Certificate Request
Check the Certificate:
```bash
kubectl describe certificate example-cert
```

Look at Events. cert-manager creates a **CertificateRequest** object.

Check CertificateRequest:
```bash
kubectl get certificaterequest
kubectl describe certificaterequest <name>
```

Events show:
- Waiting for approval
- Approved by cert-manager
- Waiting for order
- Order fulfilled
- Certificate fetched

Check Orders:
```bash
kubectl get orders
kubectl describe order <name>
```

If there is an issue, you may see:
- HTTP non-200 status code on the HTTP challenge.
- Problems with DNS pointing to the wrong IP.
- Load balancer misconfiguration.
- Router port forwarding incorrect.

Check cert-manager logs:
```bash
kubectl logs -n cert-manager <cert-manager-pod>
```

Once the order completes successfully, check secrets:
```bash
kubectl get secrets
```

You should see the TLS secret created.

---

### Verify HTTPS
Open your domain in a browser.

You should see:
- A secure connection.
- A valid certificate issued by Let’s Encrypt.
