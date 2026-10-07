## Failover in TraefikService

There's a third TraefikService strategy beyond `weighted` and `mirroring`: **`failover`**. It routes to a primary backend and automatically switches to a fallback when the primary is unhealthy — driven entirely by health checks.

### Full spec

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: my-app-failover
spec:
  failover:
    service:
      name: string        # primary backend
      namespace: string
      kind: Service|TraefikService
      port: int|string
    fallback:
      name: string        # fallback backend
      namespace: string
      kind: Service|TraefikService
      port: int|string
    healthCheck: {}        # optional — enables active health check-based failover detection
```

### Example: basic failover

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: app-failover
spec:
  failover:
    service:
      name: app-primary
      port: 80
      healthCheck:
        path: /healthz
        interval: 5s
        timeout: 3s
    fallback:
      name: app-secondary
      port: 80
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: app-route
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.example.com`)
      kind: Rule
      services:
        - name: app-failover
          kind: TraefikService
  tls:
    certResolver: letsencrypt
```

### How it decides to fail over

Failover is driven by the **K8s Service's endpoint health**, not a separate liveness probe of Traefik's own — specifically:

- If the primary Service has **zero healthy endpoints** (all backing pods are `NotReady` / failing their K8s readiness probe, or the Service has no endpoints at all), Traefik routes 100% of traffic to `fallback`.
- If the primary has at least one healthy endpoint, all traffic goes to `service` (primary) — there's no partial/weighted blending in failover mode, unlike `weighted`.
- The `healthCheck` block inside `failover.service` is Traefik's *own* active healthcheck (HTTP polling on a path) layered on top — this is what actually flips Traefik's internal state, independent of whether K8s itself has marked the pod NotReady yet. Without it, Traefik relies purely on endpoint list changes from K8s.

So in practice you generally want **both**:
1. Kubernetes readiness probes on the underlying Deployments (removes bad pods from the Service's endpoint list).
2. Traefik's own `healthCheck` on the failover's primary (faster detection, independent confirmation, doesn't wait for K8s endpoint propagation).

### Nesting failover with weighted/mirroring

Same rules as before — `failover.service`/`fallback` can point to another `TraefikService` via `kind: TraefikService`, so you can compose, e.g.:

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: region-failover
spec:
  failover:
    service:
      name: eu-west-weighted   # a weighted TraefikService (canary split within primary region)
      kind: TraefikService
      port: 80
    fallback:
      name: us-east-primary    # plain Service — DR region
      kind: Service
      port: 80
```

This gets you: normal traffic does a canary split in the primary region; if the *entire* primary region's Service goes unhealthy, everything shifts to the DR region Service.

### Failover vs. K8s-native Service failover

Plain K8s `Service` has **no failover concept** — it load-balances across whatever endpoints exist and simply excludes not-ready ones; there's no concept of "primary vs. backup" pool. If a Service has zero ready endpoints, requests just fail (connection refused / 503 depending on kube-proxy mode) — no automatic redirect to a different Service. `TraefikService.failover` is what adds that primary/backup semantic, which is otherwise something you'd have to build with something like an external DNS failover or a second-tier LB.

### Comparison against `weighted` for HA purposes

| | `weighted` | `failover` |
|---|---|---|
| Normal state | Splits traffic by percentage continuously | 100% to primary, 0% to fallback |
| Triggered by | Nothing — static split unless you edit weights | Primary's health check / endpoint state |
| Use case | Canary, A/B, gradual rollout | DR, HA pairs, active-passive backends |
| Manual intervention needed to shift traffic | Yes (edit weight values) | No — automatic on primary's health state |

### Gotcha

Failover state is **binary per the TraefikService object** — there's no "80% primary / 20% fallback during degradation" mode. If you need gradual traffic shifting based on health, that's not what `failover` does; you'd combine external monitoring + manually adjusting a `weighted` TraefikService instead.