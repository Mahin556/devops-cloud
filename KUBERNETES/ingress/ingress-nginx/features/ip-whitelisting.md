### IP Whitelisting with NGINX Ingress

The `nginx.ingress.kubernetes.io/whitelist-source-range` annotation restricts access to your service to a set of allowed client IP addresses (or CIDR ranges). Requests from IPs not in the list receive a **403 Forbidden** response.

This can be set **per‑Ingress** (via annotation) or **globally** (via the controller's ConfigMap).

---

### Per‑Ingress Example (Annotation)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: "192.168.1.0/24,10.0.0.5/32"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

- **Value**: a comma‑separated list of CIDR‑notation IP ranges.
- **Effect**: only clients from `192.168.1.0/24` and the single IP `10.0.0.5` are allowed.

---

### Global Example (ConfigMap)

To apply a default whitelist to **all** Ingress resources in the cluster, set it in the `ingress-nginx` ConfigMap (usually named `ingress-nginx-controller` in the `ingress-nginx` namespace):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  whitelist-source-range: "10.0.0.0/8,172.16.0.0/12"
```

After applying, every Ingress will inherit this whitelist **unless** overridden by a per‑Ingress annotation.

---

### Important Considerations

- The annotation uses **client IP** as seen by NGINX. If your cluster is behind a proxy, ensure the `X-Forwarded-For` header is correctly set and the controller is configured to trust it (see `use-forwarded-headers` and `enable-real-ip` config).
- CIDR ranges must be valid (e.g., `192.168.1.0/24`). Invalid values will cause NGINX to reject the configuration.
- The global ConfigMap value is a **default** – the per‑Ingress annotation always takes precedence.

---

### Quick Test

```bash
# From an allowed IP – should return 200
curl -H "X-Forwarded-For: 192.168.1.10" http://myapp.example.com/

# From a non‑allowed IP – returns 403
curl -H "X-Forwarded-For: 8.8.8.8" http://myapp.example.com/
```
