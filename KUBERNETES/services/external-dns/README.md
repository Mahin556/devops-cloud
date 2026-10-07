**ExternalDNS** is a Kubernetes tool/controller that **automatically creates and updates DNS records** based on Kubernetes resources such as Services and Ingresses.

### Example

Without ExternalDNS:

```text
Ingress
nginx.example.com
      ↓
You manually create DNS record
nginx.example.com → LoadBalancer IP
```

With ExternalDNS:

```text
Kubernetes Ingress
       ↓
ExternalDNS
       ↓
DNS Provider
(Route53 / Cloud DNS / Cloudflare)
       ↓
nginx.example.com → 34.x.x.x
```

For example:

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: nginx.example.com
```

ExternalDNS sees this and creates the DNS record automatically.

### Common use

```text
Kubernetes
   │
   ├── Ingress → ExternalDNS → DNS record
   │
   └── Service → ExternalDNS → DNS record
```

It supports providers such as **AWS Route 53, Google Cloud DNS, Azure DNS, Cloudflare**, etc.

**Important:** ExternalDNS manages **DNS records**. It does **not provide DNS resolution for Pods** like CoreDNS does.
