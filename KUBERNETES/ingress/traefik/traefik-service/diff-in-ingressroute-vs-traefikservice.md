## IngressRoute vs TraefikService

They sit at different points in the same pipeline — IngressRoute is the entrypoint that owns routing rules; TraefikService is an optional backend abstraction it can point to instead of a plain K8s Service.

| | IngressRoute | TraefikService |
|---|---|---|
| **API group** | `traefik.io/v1alpha1`, `kind: IngressRoute` | `traefik.io/v1alpha1`, `kind: TraefikService` |
| **Role in the chain** | Entry point — binds to a Traefik entrypoint (web/websecure) and holds match rules | Backend abstraction — referenced *inside* an IngressRoute's (or another TraefikService's) `services:` list |
| **Standalone use** | Yes — every route needs one | No — meaningless without something referencing it |
| **Holds match rules (`Host`, `PathPrefix`, etc.)** | Yes | No |
| **Holds TLS config** | Yes (`tls:` block — cert resolver, SNI, passthrough) | No |
| **Holds middleware refs** | Yes (`middlewares:`) | Can also chain middlewares in a `mirroring` or `weighted` service definition, but it's not its primary job |
| **Points to** | One or more `services:` entries — each can be a plain K8s `Service` **or** a `TraefikService` | One or more K8s `Services` (or nested `TraefikServices`) |
| **Purpose** | "When does this rule fire, and where does matched traffic go" | "How do I distribute/combine traffic across several backends" |
| **Native K8s equivalent** | Roughly maps to `Ingress` (but far more expressive) | No native K8s equivalent — this is Traefik-only, since core `Service` load-balances pods, not other Services |

### What TraefikService is actually for

A single K8s `Service` already load-balances across its own pod endpoints. You don't need a `TraefikService` for that case. You reach for `TraefikService` when you need to combine or split traffic **across multiple K8s Services**, which plain K8s objects can't express:

1. **Weighted round-robin** — canary/blue-green deploys, splitting traffic by percentage between two Services (e.g., two Deployments of different app versions).
2. **Mirroring** — send 100% of traffic to a primary Service and a sampled percentage to a mirror Service (for shadow-testing a new version with real traffic, without affecting responses).
3. **Nesting** — a `TraefikService` can reference other `TraefikServices`, letting you build multi-level topologies (e.g., mirror inside a weighted split).

### Example: weighted TraefikService

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: my-app-canary
spec:
  weighted:
    services:
      - name: my-app-v1
        port: 80
        weight: 90
      - name: my-app-v2
        port: 80
        weight: 10
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-route
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.example.com`)
      kind: Rule
      services:
        - name: my-app-canary
          kind: TraefikService   # note: kind must be set explicitly here
  tls:
    certResolver: letsencrypt
```

### Example: mirroring

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: my-app-mirror
spec:
  mirroring:
    name: my-app-v1        # primary — gets full traffic, response returned to client
    port: 80
    mirrors:
      - name: my-app-v2    # mirror — gets a % of requests, response discarded
        port: 80
        percent: 10
```

### Key gotcha

When an IngressRoute's `services:` entry targets a `TraefikService` instead of a plain `Service`, you **must** set `kind: TraefikService` on that entry — Traefik defaults to assuming `kind: Service` if omitted, and will fail to resolve the reference otherwise.

### Bottom line

- Use plain `Service` references in your IngressRoute for the normal case (one backend, K8s handles pod load-balancing).
- Reach for `TraefikService` only when you need cross-Service traffic shaping — weighted splits or mirroring — that a single K8s Service object can't do on its own.

---

## IngressRoute vs TraefikService — full breakdown

### 1. Full spec surface

**IngressRoute spec fields:**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: string
  namespace: string
spec:
  entryPoints: [string]              # which Traefik listeners handle this (web, websecure, custom)
  routes:
    - match: string                  # rule expression (see below)
      kind: Rule                     # always "Rule" for IngressRoute entries
      priority: int                  # higher wins on overlapping rules (default: rule length-based)
      services:
        - name: string
          namespace: string          # cross-namespace ref allowed
          kind: Service|TraefikService
          port: int|string
          weight: int                # only meaningful with multiple entries here (implicit weighting)
          sticky:
            cookie:
              name: string
              secure: bool
              httpOnly: bool
              sameSite: string
              maxAge: int
          strategy: RoundRobin        # LB strategy for this service's own endpoints
          passHostHeader: bool
          responseForwarding:
            flushInterval: string
          scheme: http|https|h2c
          serversTransport: string    # ref to ServersTransport CRD (mTLS to backend, skip verify, etc.)
          healthCheck:
            path: string
            interval: string
            timeout: string
      middlewares:
        - name: string
          namespace: string
      syntax: v2|v3                  # rule matcher syntax version (Traefik v3+)
  tls:
    secretName: string
    options:
      name: string
      namespace: string
    certResolver: string
    domains:
      - main: string
        sans: [string]
    store:
      name: string
```

**TraefikService spec fields:**

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: string
spec:
  # mutually exclusive: weighted OR mirroring
  weighted:
    services:
      - name: string
        namespace: string
        kind: Service|TraefikService  # nestable
        port: int|string
        weight: int
        sticky:
          cookie:
            name: string
            secure: bool
    sticky:                           # sticky across the WHOLE weighted group (not per-service)
      cookie:
        name: string
  mirroring:
    name: string                      # primary backend
    namespace: string
    kind: Service|TraefikService
    port: int|string
    mirrorBody: bool                  # whether to mirror the request body too (default true)
    maxBodySize: int                  # bytes; -1 = unlimited
    mirrors:
      - name: string
        namespace: string
        kind: Service|TraefikService
        port: int|string
        percent: int                  # 0-100
```

Notice: IngressRoute has no `weighted`/`mirroring` block at all — that logic lives *only* in TraefikService. IngressRoute's own multi-service list does support a crude `weight:` per entry (basic weighted round robin), but it lacks sticky-across-group, mirroring, and nesting — which is exactly why TraefikService exists as a separate object.

---

### 2. Rule matcher syntax (IngressRoute only)

TraefikService has no concept of "rules" — matching is 100% IngressRoute's job.

```
Host(`example.com`)
Host(`example.com`) && PathPrefix(`/api`)
HostRegexp(`^www\.(example|test)\.com$`)
Path(`/exact-path`)
PathPrefix(`/prefix`)
PathRegexp(`^/api/v[0-9]+/`)
Method(`GET`, `POST`)
Headers(`X-Custom`, `value`)
HeadersRegexp(`X-Custom`, `^value.*`)
Query(`param=value`)
ClientIP(`10.0.0.0/24`)
```

Combine with `&&`, `||`, `!`. This is the single biggest functional gap vs. plain K8s `Ingress`/`Service`, which only does host+path.

---

### 3. Nesting depth — TraefikService referencing TraefikService

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: region-split
spec:
  weighted:
    services:
      - name: canary-mirror-group   # <- another TraefikService
        kind: TraefikService
        port: 80
        weight: 80
      - name: stable-v1
        kind: Service
        port: 80
        weight: 20
---
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: canary-mirror-group
spec:
  mirroring:
    name: app-v2
    port: 80
    mirrors:
      - name: app-v2-shadow
        port: 80
        percent: 25
```

IngressRoute has **no nesting** — it's always the top-level object, never referenced by anything else.

---

### 4. Sticky sessions — where they can live

| Location | Scope |
|---|---|
| `IngressRoute.spec.routes[].services[].sticky` | Sticky to one specific K8s Service's pods |
| `TraefikService.spec.weighted.services[].sticky` | Sticky to one member of the weighted group |
| `TraefikService.spec.weighted.sticky` | Sticky across the **entire weighted group** — once a client lands on v1 or v2, they stay there even on refresh, rather than being re-weighted every request |

That group-level sticky is TraefikService-exclusive — you cannot express "stick to whichever backend was chosen" using IngressRoute's flat `services:` list alone.

---

### 5. Health checks and server transport

Both `IngressRoute.services[]` and `TraefikService.weighted.services[]` accept `healthCheck` and `serversTransport` — these are per-backend-reference, not per-object-type, so functionally identical either way. The difference is *where you attach the wrapping logic* (routing+TLS vs. distribution strategy).

---

### 6. Status/observability differences

- `IngressRoute` shows up in `kubectl get ingressroute` with the `Host()` rule as a column — easy to audit routing at a glance.
- `TraefikService` shows up in `kubectl get traefikservice` but has no rule/host info — you have to cross-reference which IngressRoute(s) point to it. There's no owner-reference link by default; it's a plain named reference, so orphaned TraefikServices (nothing pointing to them) won't error, just silently do nothing.

---

### 7. When you'd reach for TraefikService — concrete patterns

| Pattern | Config |
|---|---|
| Canary release (10% to new version) | `weighted` with two K8s Services, weights 90/10 |
| Blue-green cutover | `weighted`, flip weights 100/0 → 0/100 across deploys, no IngressRoute edit needed |
| Shadow testing (new version sees prod traffic, doesn't affect response) | `mirroring`, percent tunable, response discarded |
| A/B testing session-consistent | `weighted` + group-level `sticky.cookie` |
| Multi-region weighted routing behind one host rule | nested `weighted` TraefikServices |

If you're doing none of the above — single Service, single version, no traffic shaping — you never need a TraefikService. Just reference the K8s `Service` directly in `IngressRoute.spec.routes[].services[]`.

---

### 8. One-line mental model

**IngressRoute** = "when this request comes in, here's the TLS/rule/middleware, send it *here*."
**TraefikService** = "*here* is actually a formula for splitting or duplicating traffic across multiple backends" — a pluggable value you can drop into that `services:` slot instead of a plain name.

---

