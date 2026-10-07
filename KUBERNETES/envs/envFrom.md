- `envFrom` allows you to inject all keys from a `ConfigMap` or `Secret` as environment variables in a container.
- It avoids defining each variable individually in `env`.
- Works with `ConfigMaps` and `Secrets`.

#### From ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  APP_MODE: "production"
  LOG_LEVEL: "debug"
---
envFrom:
  - configMapRef:
      name: my-config
```
Each key in `my-config` becomes an environment variable with the same name.

#### From Secret
```yaml
envFrom:
  - secretRef:
      name: my-secret
```
Each key in my-secret becomes an env var.

#### Multiple envFrom entries
You can have more than one envFrom, combining ConfigMaps and Secrets.
```yaml
envFrom:
  - configMapRef:
      name: my-config
  - secretRef:
      name: my-secret
```
All keys from both sources are injected.
Order matters: if keys overlap, the last one wins.


#### Optional Sources
You can make a ConfigMap or Secret optional, so the Pod won’t fail if it doesn’t exist.
```yaml
envFrom:
  - configMapRef:
      name: my-config
      optional: true
  - secretRef:
      name: my-secret
      optional: true
```
Use case: different environments may have different ConfigMaps or Secrets.

#### Prefixing Environment Variables
You can add a prefix to all keys from the source to avoid naming conflicts.
```yaml
envFrom:
  - configMapRef:
      name: my-config
      optional: true
      prefix: CONFIG_
```
Example: if my-config has APP_MODE, container sees CONFIG_APP_MODE.
Use case: avoid collisions when multiple ConfigMaps/Secrets provide similar keys.

#### Use Cases
* Inject all app configuration at once: ConfigMaps often store many app settings (APP_MODE, LOG_LEVEL, API_URL) → inject with one envFrom.
* Inject secrets easily: DB credentials, API tokens → inject all at once using envFrom: secretRef.
* Environment-specific overrides: Use optional sources for staging vs production.
* Prefixing to avoid collisions: Combine multiple ConfigMaps/Secrets without overwriting existing env vars.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_MODE: "production"
  LOG_LEVEL: "info"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
stringData:
  DB_USER: "admin"
  DB_PASS: "password123"
---
apiVersion: v1
kind: Pod
metadata:
  name: envfrom-demo
spec:
  containers:
    - name: app
      image: busybox
      command: ["sh", "-c"]
      args: ["env; sleep 3600"]
      envFrom:
        - configMapRef:
            name: app-config
            prefix: CFG_
        - secretRef:
            name: app-secret
            optional: true
```