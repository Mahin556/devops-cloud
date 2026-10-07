## How Helm Dependencies Work

Helm dependencies let you bundle multiple charts into a single parent chart. The parent chart automatically manages and deploys the subcharts (dependencies), much like `npm` or `pip` manage packages.

### Declaring Dependencies in `Chart.yaml`

Dependencies are declared under the `dependencies` key:

```yaml
apiVersion: v2
name: my-web-app
version: 1.0.0
dependencies:
  - name: postgresql
    version: "15.x.x"
    repository: "https://charts.bitnami.com/bitnami"
  - name: redis
    version: "18.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled   # optional toggle
```

Each dependency specifies:
- `name` – the subchart name.
- `version` – a SemVer constraint.
- `repository` – the chart repository URL (or an `oci://` URL for OCI registries).
- `condition` – an optional path to a boolean in `values.yaml` that enables/disables the subchart.
- `tags` – optional labels to group subcharts for bulk toggling.

### Resolving and Downloading Dependencies

Helm provides two commands:

| Command | What it does |
|---|---|
| `helm dependency update ./my-chart` | Reads `Chart.yaml`, resolves versions, downloads `.tgz` files into `charts/`, and creates/updates `Chart.lock`. |
| `helm dependency build ./my-chart` | Reconstructs `charts/` using the exact versions pinned in `Chart.lock`. Used in CI/CD for reproducibility. |

**`Chart.lock`** pins the exact versions downloaded. Commit it to Git so everyone gets the same subchart versions.

### Configuring Subchart Values

Values for a subchart are nested under a top-level key matching the subchart's name in the parent's `values.yaml`:

```yaml
# parent values.yaml
replicaCount: 3

postgresql:
  auth:
    database: "prod_db"
    username: "admin"
```

When you run `helm install`, Helm merges the parent values with the subchart's defaults, using the subchart name as the mapping key.

### Conditional Toggles

- **`condition`** – binds the subchart's deployment to a boolean in `values.yaml` (e.g., `condition: redis.enabled`). If `false`, the subchart is skipped entirely.
- **`tags`** – groups multiple subcharts under a single label (e.g., `tags: [databases]`), allowing you to enable/disable whole segments at once.

Example to disable a subchart during install:

```bash
helm install my-release ./my-app --set mongodb.enabled=false
```

### Installation Lifecycle

When you run `helm install my-release ./my-app`, Helm:
1. Resolves dependencies (using `charts/` if already built).
2. Merges values from the parent and all subcharts.
3. Renders all templates from the parent and subcharts into one set of Kubernetes manifests.
4. Submits them to the cluster in dependency order (subcharts first, then parent resources).

---

## Complete Example: Parent Chart with a MongoDB Subchart

Suppose you have a Node.js API chart (`my-api`) that needs MongoDB.

**Step 1 – Directory structure:**
```
my-api/
├── Chart.yaml
├── values.yaml
├── charts/          # empty initially
└── templates/
    └── deployment.yaml
```

**Step 2 – Declare MongoDB in `Chart.yaml`:**
```yaml
apiVersion: v2
name: my-api
version: 1.0.0
appVersion: "18.0.0"

dependencies:
  - name: mongodb
    version: "15.6.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: mongodb.enabled
```

**Step 3 – Fetch the dependency:**
```bash
helm dependency update ./my-api
```
This downloads `mongodb-15.6.3.tgz` into `my-api/charts/` and creates `Chart.lock`.

**Step 4 – Configure both charts in `values.yaml`:**
```yaml
replicaCount: 2
image:
  repository: myregistry/my-node-api
  tag: "v1.0"

mongodb:
  enabled: true
  auth:
    rootPassword: "SuperSecurePassword123"
    database: "users_db"
  architecture: "standalone"
```

**Step 5 – Reference the subchart in templates:**
Helm names subchart services as `<release-name>-<subchart-name>`. In `deployment.yaml`:
```yaml
env:
  - name: MONGO_URL
    value: "mongodb://admin:{{ .Values.mongodb.auth.rootPassword }}@{{ .Release.Name }}-mongodb:27017/{{ .Values.mongodb.auth.database }}"
```

**Step 6 – Install the whole stack:**
```bash
helm install production-app ./my-api
```

To install without MongoDB:
```bash
helm install production-app ./my-api --set mongodb.enabled=false
```