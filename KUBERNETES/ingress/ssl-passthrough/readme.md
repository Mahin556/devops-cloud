# NGINX Ingress — Backend HTTPS: Complete Guide
# Two approaches with full working examples

---

## THE PROBLEM — Why this error happens

```
Client ──HTTP──► Ingress Controller ──HTTP──► Backend (expects HTTPS)
                                              ↑
                                         Backend returns: 400 Bad Request
                                         "The plain HTTP request was sent
                                          to HTTPS port"
                                          or SSL handshake error
```

The Ingress Controller by default:
1. Terminates TLS from the client (if configured)
2. Forwards plain HTTP to the backend pod

If your backend ONLY speaks HTTPS (like ArgoCD, Grafana with TLS, internal
services with self-signed certs), the forwarded HTTP request fails.

---

## APPROACH 1 — SSL Passthrough

The Ingress Controller does NOT decrypt traffic.
It just forwards the raw TCP/TLS stream directly to the backend.
The backend handles TLS itself end-to-end.

```
Client ──TLS──► Ingress Controller ──TLS──► Backend
                    (passthrough)
                 NO termination here
```

### Step 1: Enable SSL Passthrough on the Ingress Controller

The flag must be added to the nginx ingress controller deployment args.
Without this flag, the ssl-passthrough annotation is SILENTLY IGNORED.

```yaml
# Option A: If installed via Helm, add to values.yaml:
controller:
  extraArgs:
    enable-ssl-passthrough: "true"

# Then upgrade:
# helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
#   -n ingress-nginx -f values.yaml
```

```yaml
# Option B: Patch the deployment directly
# kubectl edit deployment ingress-nginx-controller -n ingress-nginx
# Add under: spec.template.spec.containers[0].args:
    args:
      - /nginx-ingress-controller
      - --election-id=ingress-nginx-leader
      - --controller-class=k8s.io/ingress-nginx
      - --ingress-class=nginx
      - --configmap=$(POD_NAMESPACE)/ingress-nginx-controller
      - --enable-ssl-passthrough     # ← ADD THIS LINE
```

```bash
# Verify it's enabled:
kubectl exec -n ingress-nginx \
  $(kubectl get pods -n ingress-nginx -o name | grep controller | head -1) \
  -- /nginx-ingress-controller --help | grep ssl-passthrough
```

### Step 2: Deploy a backend that serves HTTPS

```yaml
# backend-https-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: argocd-server
  template:
    metadata:
      labels:
        app: argocd-server
    spec:
      containers:
        - name: argocd-server
          image: quay.io/argoproj/argocd:v2.10.0
          args:
            - argocd-server
            # NOTE: No --insecure flag here = ArgoCD serves HTTPS itself
          ports:
            - containerPort: 8080    # HTTP (ArgoCD redirects this to HTTPS)
            - containerPort: 8083    # HTTPS (ArgoCD's own TLS)
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
spec:
  selector:
    app: argocd-server
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8083    # points to ArgoCD's HTTPS port
```

### Step 3: Create the Ingress with SSL Passthrough annotation

```yaml
# ingress-passthrough.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-passthrough
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    # ↑ CRITICAL: raw TLS forwarded directly to backend
    # nginx does NOT decrypt — backend cert is what client sees

    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    # ↑ tells nginx this backend speaks HTTPS (not HTTP)
    # Used together with ssl-passthrough
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443   # must point to the HTTPS port on the service
```

### How SSL Passthrough works at the TCP level

```
Client connects to: argocd.example.com:443
         │
         ▼
NGINX Ingress Controller receives raw TCP connection
         │
         │ Reads SNI (Server Name Indication) from TLS ClientHello
         │ WITHOUT decrypting — SNI is in plaintext in TLS handshake
         │ SNI = "argocd.example.com"
         │
         │ Matches against ingress rules by hostname
         │
         ▼
NGINX opens a new TCP connection to backend pod port 443
         │
         ▼
Forwards raw bytes between client ←→ backend
TLS handshake happens DIRECTLY between client and backend pod
NGINX never sees plaintext — it's just a TCP proxy at this point
         │
         ▼
Client sees: backend pod's own TLS certificate (self-signed or real)
```

### Important limitation of SSL Passthrough

```
Because NGINX operates at Layer 4 (TCP) for passthrough, NOT Layer 7 (HTTP):

❌ Cannot route by URL path (/api vs /web)
   All traffic goes to ONE backend per hostname

❌ Cannot add headers (X-Real-IP, X-Forwarded-For)
   NGINX can't modify encrypted traffic

❌ Cannot use other NGINX annotations (rate-limit, auth, etc.)
   These all require Layer 7 access

❌ Cannot have multiple backends under same host
   Only one path: / supported (pathType must match all)

✅ Works for: ArgoCD, Grafana, any service with its own TLS cert
✅ End-to-end encryption preserved
✅ Client sees the actual backend certificate
```

---

## APPROACH 2 — NGINX terminates TLS, re-encrypts to backend (HTTPS backend)

NGINX has its OWN cert for the client.
Backend also uses HTTPS (maybe self-signed).
NGINX verifies or ignores the backend's cert.

```
Client ──TLS──► NGINX (terminates) ──HTTPS──► Backend
               NGINX's cert            Backend's cert
               (trusted, real)        (may be self-signed)
```

### When to use this

Use when:
- You want NGINX to handle the client-facing cert (Let's Encrypt, real CA)
- Your backend already requires HTTPS but has a self-signed/internal cert
- You need path-based routing, headers, rate-limiting, etc. (all NGINX features work)

### Step 1: Create TLS secret for the ingress (client-facing)

```bash
# Using cert-manager (recommended):
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  secretName: argocd-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - argocd.example.com
EOF

# Or self-signed for testing:
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=argocd.example.com"

kubectl create secret tls argocd-tls-secret \
  --cert=tls.crt \
  --key=tls.key \
  -n argocd
```

### Step 2: Ingress with backend-protocol HTTPS

```yaml
# ingress-https-backend.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-https-backend
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    # ↑ tells NGINX to use HTTPS when talking to the backend service
    # NGINX will forward requests over HTTPS (port 443 on the service)

    nginx.ingress.kubernetes.io/ssl-verify-backend: "false"
    # ↑ OPTIONAL: skips verification of backend's certificate
    # Use when backend has self-signed cert
    # Remove this if backend has a cert from a trusted CA

    # OPTIONAL: Use these for path-based routing (works because NGINX decrypts):
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    # Needed for ArgoCD's streaming connections

spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - argocd.example.com
      secretName: argocd-tls-secret    # NGINX uses this cert for clients
  rules:
    - host: argocd.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443    # service's HTTPS port
```

### How HTTPS backend works

```
Client connects to: argocd.example.com:443
         │
         ▼
NGINX receives TLS connection
NGINX terminates TLS using: argocd-tls-secret (Let's Encrypt cert)
Client sees: trusted, real certificate ✅
         │
         ▼
NGINX now has plaintext HTTP request internally
NGINX applies: rate-limits, auth, path routing, headers etc.
         │
         ▼
NGINX opens NEW HTTPS connection to backend pod:443
If ssl-verify-backend: "false" → accepts self-signed cert without error
Backend sees: NGINX as the client (with its own internal cert)
         │
         ▼
Response flows back:
Backend → NGINX (decrypts backend's TLS)
NGINX → Client (encrypts with Let's Encrypt cert)
```

---

## APPROACH 3 — Force backend to accept HTTP (simplest)

If you control the backend, add `--insecure` flag to disable its TLS.
Then normal HTTP Ingress works without any special annotations.

```yaml
# Example: ArgoCD in insecure mode
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  template:
    spec:
      containers:
        - name: argocd-server
          args:
            - argocd-server
            - --insecure    # ← ArgoCD now accepts plain HTTP
          # Now the Ingress can forward HTTP normally
```

```yaml
# Normal Ingress — no special annotations needed:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-http
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Client still gets HTTPS (NGINX handles it)
    # Backend gets plain HTTP (simpler)
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - argocd.example.com
      secretName: argocd-tls-secret
  rules:
    - host: argocd.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80    # HTTP port now
```

---

## APPROACH 4 — Bypass Ingress with NodePort or LoadBalancer

When you don't want Ingress involved at all:

```yaml
# NodePort — access via node-ip:nodePort
apiVersion: v1
kind: Service
metadata:
  name: argocd-nodeport
  namespace: argocd
spec:
  type: NodePort
  selector:
    app: argocd-server
  ports:
    - name: https
      port: 443
      targetPort: 8083
      nodePort: 30443    # access: https://node-ip:30443

---
# LoadBalancer — gets external IP (cloud or MetalLB)
apiVersion: v1
kind: Service
metadata:
  name: argocd-lb
  namespace: argocd
spec:
  type: LoadBalancer
  selector:
    app: argocd-server
  ports:
    - name: https
      port: 443
      targetPort: 8083
  # Cloud: gets public IP automatically
  # kind/bare-metal: use MetalLB to assign IP
```

---

## Comparison table — which approach to pick

| | SSL Passthrough | HTTPS Backend | Force HTTP | NodePort/LB |
|---|---|---|---|---|
| Client cert | Backend's own cert | NGINX's cert (Let's Encrypt) | NGINX's cert | Backend's own cert |
| Path routing | ❌ No | ✅ Yes | ✅ Yes | ❌ No |
| Headers injection | ❌ No | ✅ Yes | ✅ Yes | ❌ No |
| Backend cert needed | ✅ Yes | Any (self-signed ok) | ❌ No | ✅ Yes |
| Config complexity | Medium | Medium | Low | Low |
| Best for | ArgoCD, Grafana | Internal HTTPS services | Development | Direct access |

---

## Quick debug commands

```bash
# Check if ssl-passthrough is enabled on controller:
kubectl describe pod -n ingress-nginx \
  $(kubectl get pods -n ingress-nginx -o name | grep controller) \
  | grep -A20 "Args:"

# Check ingress annotations were applied:
kubectl describe ingress <name> -n <namespace>

# Test HTTP vs HTTPS response from pod directly (bypass ingress):
kubectl exec -n argocd \
  $(kubectl get pods -n argocd -l app=argocd-server -o name) \
  -- wget -qO- --no-check-certificate https://localhost:8083/healthz

# Test via ingress:
curl -k https://argocd.example.com/healthz
curl -v https://argocd.example.com/healthz 2>&1 | grep -E "SSL|TLS|certificate|subject"
```