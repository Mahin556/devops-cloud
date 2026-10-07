This is a good example of **Traefik multi-layer routing**. The important idea is that the parent router performs common processing first, and the child router makes the final service decision based on the modified request.

Based strictly on the material you provided, the structure is:

```text
                         Client
                           |
                           | /api/...
                           v
                    +---------------+
                    |  api-parent   |
                    |  PathPrefix   |
                    |     /api      |
                    +---------------+
                           |
                           v
                  auth-middleware
                    (ForwardAuth)
                           |
                     adds headers
                           |
                 +---------+---------+
                 |                   |
          X-User-Role=admin    X-User-Role=user
                 |                   |
                 v                   v
          admin-service        user-service
                 |
                 |
          no matching role
                 |
                 v
          default-service
```

## 1. Parent router

The parent router is the entry point for `/api` requests:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute

metadata:
  name: api-parent
  namespace: apps

spec:
  entryPoints:
    - websecure

  routes:
    - match: PathPrefix(`/api`)
      kind: Rule

      middlewares:
        - name: auth-middleware

  tls: {}
```

Notice there is **no `services:` section**.

According to your source, this makes it a parent/intermediate router whose job is to process the request before a child router makes the final routing decision.

---

# 2. Authentication middleware

The parent uses `ForwardAuth`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware

metadata:
  name: auth-middleware
  namespace: apps

spec:
  forwardAuth:
    address: "http://auth-service.apps.svc.cluster.local:8080/auth"

    authResponseHeaders:
      - X-User-Role
      - X-User-Name
```

The important part is:

```yaml
authResponseHeaders:
  - X-User-Role
  - X-User-Name
```

The authentication service can return information such as:

```text
X-User-Role: admin
X-User-Name: Mahin
```

Those headers are then available for the child router's matching rules.

---

# 3. Child router

The child router references the parent with `parentRefs`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute

metadata:
  name: api-routing-logic
  namespace: apps

spec:
  parentRefs:
    - name: api-parent
      namespace: apps

  routes:

    # Admin users
    - match: HeadersRegexp(`X-User-Role`, `admin`)
      kind: Rule

      services:
        - name: admin-service
          port: 8080

    # Normal users
    - match: HeadersRegexp(`X-User-Role`, `user`)
      kind: Rule

      services:
        - name: user-service
          port: 8080

    # Catch-all
    - match: PathPrefix(`/`)
      kind: Rule

      priority: 0

      services:
        - name: default-service
          port: 8080
```

The important difference is that the child **does have `services:`**.

---

# 4. Complete routing logic

Suppose the client requests:

```text
https://example.com/api/users
```

### Step 1 — Parent router

The parent checks:

```yaml
match: PathPrefix(`/api`)
```

The request matches.

```text
/api/users
   ↓
api-parent
```

### Step 2 — Authentication

The parent executes:

```yaml
middlewares:
  - name: auth-middleware
```

The auth service validates the request.

It could return:

```text
X-User-Role: admin
X-User-Name: Mahin
```

### Step 3 — Child router

The child now evaluates:

```yaml
HeadersRegexp(`X-User-Role`, `admin`)
```

It matches.

Therefore:

```text
admin-service:8080
```

receives the request.

---

# 5. Admin request

```text
Client
  |
  | /api/users
  v
api-parent
  |
  v
ForwardAuth
  |
  +--> X-User-Role: admin
  |
  v
api-routing-logic
  |
  +--> HeadersRegexp(..., admin)
  |
  v
admin-service:8080
```

---

# 6. Normal user request

Suppose the authentication service returns:

```http
X-User-Role: user
```

The child rule:

```yaml
- match: HeadersRegexp(`X-User-Role`, `user`)
```

matches.

Traffic goes to:

```text
user-service:8080
```

Flow:

```text
Client
  ↓
api-parent
  ↓
ForwardAuth
  ↓
X-User-Role: user
  ↓
api-routing-logic
  ↓
user-service
```

---

# 7. Unknown/no role

Suppose authentication doesn't produce:

```text
admin
```

or

```text
user
```

Then neither specific rule matches.

The catch-all rule:

```yaml
- match: PathPrefix(`/`)
  priority: 0
```

can handle the request:

```text
default-service:8080
```

Your source specifically emphasizes using priority `0` for the catch-all so more specific routes are evaluated before it.

---

# 8. Why `parentRefs` is important

The child has:

```yaml
parentRefs:
  - name: api-parent
    namespace: apps
```

This establishes:

```text
api-parent
     |
     +---- api-routing-logic
```

The child does **not** define its own:

```yaml
entryPoints:
tls:
```

because, according to your source, those belong to the root router.

---

# 9. Root vs intermediate vs leaf

### Root router

Example:

```yaml
spec:
  entryPoints:
    - websecure

  routes:
    - match: PathPrefix(`/api`)
      kind: Rule

      middlewares:
        - name: auth-middleware

  tls: {}
```

It can have:

```text
entryPoints
TLS
middleware
```

but doesn't necessarily need a service when it is acting as a parent.

### Intermediate router

Has:

```yaml
parentRefs:
```

but:

```text
no service
no entryPoints
no TLS
```

It can have children.

### Leaf router

Has:

```yaml
parentRefs:
```

and:

```yaml
services:
```

This is where the request finally reaches an application.

---

# 10. Complete relationship

```text
                    ROOT
               api-parent
                    |
              Middleware
             ForwardAuth
                    |
                    v
               INTERMEDIATE
          api-routing-logic
             /      |       \
            /       |        \
           v        v         v
        admin     user      default
       service   service    service
          |         |          |
          v         v          v
        Pods      Pods       Pods
```

The key idea from your material is **progressive request enrichment**:

```text
Request
   ↓
Parent rule
   ↓
Authentication
   ↓
Headers added
   ↓
Child rule
   ↓
Final service
```

That is what makes multi-layer routing different from simply having several independent routers.
